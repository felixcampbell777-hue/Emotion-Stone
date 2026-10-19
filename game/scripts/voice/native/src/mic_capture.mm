// Copyright (c) 2026 World Rise contributors. SPDX-License-Identifier: MIT
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>
#include <array>
#include <mutex>
#include <atomic>
#include <cmath>
using namespace godot;

class WorldRiseMicCapture : public RefCounted {
    GDCLASS(WorldRiseMicCapture, RefCounted)
    static constexpr size_t CAPACITY = 9600; // 200ms at 48kHz; bounded independently of the main thread.
    struct Frame { float value; };
    std::array<Frame, CAPACITY> ring{};
    std::mutex lock;
    size_t head=0, tail=0, count=0;
    std::atomic<bool> running{false};
    std::atomic<int64_t> dropped{0};
    AVAudioEngine *__strong engine = nil;
    String status = "Microphone off";
    String selected = "Default";
    double sample_rate=48000;

    static AudioDeviceID device_for_name(const String &name) {
        AudioObjectPropertyAddress prop{kAudioHardwarePropertyDevices,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
        UInt32 bytes=0;
        if(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject,&prop,0,nullptr,&bytes)!=noErr || bytes>65536) return kAudioObjectUnknown;
        std::array<AudioDeviceID,4096> devices{};
        if(bytes>sizeof(devices) || AudioObjectGetPropertyData(kAudioObjectSystemObject,&prop,0,nullptr,&bytes,devices.data())!=noErr) return kAudioObjectUnknown;
        for(size_t i=0;i<bytes/sizeof(AudioDeviceID);++i) {
            CFStringRef cf=nullptr;
            UInt32 size=sizeof(cf);
            AudioObjectPropertyAddress nameprop{kAudioObjectPropertyName,kAudioObjectPropertyScopeGlobal,kAudioObjectPropertyElementMain};
            if(AudioObjectGetPropertyData(devices[i],&nameprop,0,nullptr,&size,&cf)==noErr && cf) {
                NSString *ns=CFBridgingRelease(cf);
                String full=String::utf8(ns.UTF8String)+" ("+String::num_int64(devices[i])+")";
                if(full==name || String::utf8(ns.UTF8String)==name) return devices[i];
            }
        }
        return kAudioObjectUnknown;
    }
public:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("start_capture","request_permission"),&WorldRiseMicCapture::start_capture,DEFVAL(false));
        ClassDB::bind_method(D_METHOD("stop_capture"),&WorldRiseMicCapture::stop_capture);
        ClassDB::bind_method(D_METHOD("get_frames_available"),&WorldRiseMicCapture::get_frames_available);
        ClassDB::bind_method(D_METHOD("get_buffer","frames"),&WorldRiseMicCapture::get_buffer);
        ClassDB::bind_method(D_METHOD("clear_buffer"),&WorldRiseMicCapture::clear_buffer);
        ClassDB::bind_method(D_METHOD("get_sample_rate"),&WorldRiseMicCapture::get_sample_rate);
        ClassDB::bind_method(D_METHOD("get_status"),&WorldRiseMicCapture::get_status);
        ClassDB::bind_method(D_METHOD("is_running"),&WorldRiseMicCapture::is_running);
        ClassDB::bind_method(D_METHOD("get_permission"),&WorldRiseMicCapture::get_permission);
        ClassDB::bind_method(D_METHOD("set_device","device"),&WorldRiseMicCapture::set_device);
        ClassDB::bind_method(D_METHOD("get_dropped_frames"),&WorldRiseMicCapture::get_dropped_frames);
    }
    String get_permission() const {
        switch([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
            case AVAuthorizationStatusAuthorized:return "authorized";
            case AVAuthorizationStatusNotDetermined:return "not_determined";
            case AVAuthorizationStatusDenied:return "denied";
            case AVAuthorizationStatusRestricted:return "restricted";
        }
        return "unavailable";
    }
    bool start_capture(bool request_permission=false) {
        stop_capture();
        if(get_permission()!="authorized") {
            if(get_permission()=="not_determined" && request_permission) {
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {}];
                status="Microphone permission requested: enable again after responding";
            } else status="Microphone permission "+get_permission()+": check system Privacy settings";
            return false;
        }
        @try {
            engine=[[AVAudioEngine alloc] init];
            AVAudioInputNode *input=engine.inputNode;
            if(selected!="Default") {
                AudioDeviceID id=device_for_name(selected);
                if(id==kAudioObjectUnknown || AudioUnitSetProperty(input.audioUnit,kAudioOutputUnitProperty_CurrentDevice,kAudioUnitScope_Global,0,&id,sizeof(id))!=noErr) {
                    status="Selected microphone unavailable";engine=nil;return false;
                }
            }
            AVAudioFormat *format=[input outputFormatForBus:0];
            sample_rate=format.sampleRate;
            if(!std::isfinite(sample_rate) || sample_rate<8000 || sample_rate>96000 || format.channelCount==0) {
                status="Unsupported microphone format";engine=nil;return false;
            }
            [input installTapOnBus:0 bufferSize:960 format:format block:^(AVAudioPCMBuffer *buffer,AVAudioTime *when) {
                if(!running.load(std::memory_order_relaxed)) return;
                if(!lock.try_lock()) {dropped.fetch_add(buffer.frameLength);return;}
                float *const *channels=buffer.floatChannelData;
                if(channels) {
                    for(AVAudioFrameCount i=0;i<buffer.frameLength;++i) {
                        float value=channels[0][i];
                        if(buffer.format.channelCount>1) value=(value+channels[1][i])*.5f;
                        if(!std::isfinite(value)) value=0;
                        value=std::fmax(-1.f,std::fmin(1.f,value));
                        if(count==CAPACITY){head=(head+1)%CAPACITY;--count;++dropped;}
                        ring[tail]={value};tail=(tail+1)%CAPACITY;++count;
                    }
                }
                lock.unlock();
            }];
            NSError *error=nil;
            running=true;
            if(![engine startAndReturnError:&error]) {
                running=false;
                status="Microphone start failed: "+String::utf8(error.localizedDescription.UTF8String ?: "unknown error");
                [input removeTapOnBus:0];engine=nil;return false;
            }
            status="Microphone ready";
            return true;
        } @catch(NSException *exception) {
            running=false;if(engine){[engine stop];@try{[engine.inputNode removeTapOnBus:0];}@catch(NSException *ignored){}}engine=nil;status="Microphone unavailable: "+String::utf8(exception.reason.UTF8String ?: "audio error");return false;
        }
    }
    void stop_capture() {
        running=false;
        if(engine) {
            [engine stop];
            @try {[engine.inputNode removeTapOnBus:0];} @catch(NSException *exception) {}
            engine=nil;
        }
        clear_buffer();status="Microphone off";
    }
    void clear_buffer(){std::lock_guard<std::mutex> guard(lock);head=tail=count=0;}
    int64_t get_frames_available(){std::lock_guard<std::mutex> guard(lock);return count;}
    PackedVector2Array get_buffer(int64_t frames){
        PackedVector2Array result;
        if(frames<=0 || frames>CAPACITY)return result;
        std::lock_guard<std::mutex> guard(lock);
        if(count<size_t(frames))return result;
        result.resize(frames);
        for(int64_t i=0;i<frames;++i){float value=ring[head].value;result.set(i,Vector2(value,value));head=(head+1)%CAPACITY;--count;}
        return result;
    }
    bool set_device(const String &device){bool was_running=running;stop_capture();selected=device;return !was_running || start_capture(false);}
    bool is_running() const{return running;}
    double get_sample_rate() const{return sample_rate;}
    String get_status() const{return status;}
    int64_t get_dropped_frames() const{return dropped;}
    ~WorldRiseMicCapture(){stop_capture();}
};
static void initialize(ModuleInitializationLevel level){if(level==MODULE_INITIALIZATION_LEVEL_SCENE)ClassDB::register_class<WorldRiseMicCapture>();}
static void terminate(ModuleInitializationLevel level){}
extern "C" GDExtensionBool GDE_EXPORT world_rise_mic_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization){
    GDExtensionBinding::InitObject init(get_proc,library,initialization);
    init.register_initializer(initialize);init.register_terminator(terminate);init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();
}
