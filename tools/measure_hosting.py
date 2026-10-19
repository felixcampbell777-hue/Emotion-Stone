"""Measure an isolated Docker fixture; optionally stress accepted bulk checkpoints."""
import argparse
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]


def command(arguments, timeout=15):
    result = subprocess.run(['docker', *arguments], capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return result.stdout.strip()


def memory_mib(value):
    number = value.split()[0]
    for suffix, multiplier in [('GiB',1024),('MiB',1),('KiB',1/1024),('GB',1000**3/1024**2),('MB',1000**2/1024**2),('kB',1000/1024**2),('B',1/1024**2)]:
        if number.endswith(suffix):
            return float(number[:-len(suffix)]) * multiplier
    raise ValueError('Unknown memory unit: ' + value)


def numeric_metrics(value, prefix=''):
    for key, item in value.items():
        name = prefix + str(key)
        if isinstance(item, dict):
            yield from numeric_metrics(item, name + '.')
        elif isinstance(item, (int, float)) and not isinstance(item, bool):
            yield name, item


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--container', default='wr-hosting-fixture-world-rise-1')
    parser.add_argument('--seconds', type=int, default=30)
    parser.add_argument('--expect-players', type=int, default=8)
    parser.add_argument('--bulk-save-every', type=float, default=0)
    args = parser.parse_args()
    if not 1 <= args.seconds <= 600 or not 0 <= args.expect_players <= 8 or args.bulk_save_every < 0:
        parser.error('Invalid bounded measurement options')
    if args.bulk_save_every and not args.container.startswith('wr-hosting-fixture-'):
        parser.error('Mutation stress is restricted to the disposable wr-hosting-fixture Compose project')
    config = json.loads(command(['inspect',args.container]))[0]
    ready = json.loads(command(['exec',args.container,'cat','/data/ready.json']))
    if not ready.get('ready') or ready.get('storage_error') or ready.get('players',0) < args.expect_players:
        raise ValueError('Fixture is not healthy with the expected players; no bulk saves were requested')
    started = time.monotonic()
    next_save = started + args.bulk_save_every
    samples = []
    saves = []
    errors = []
    while time.monotonic() - started < args.seconds:
        stats = json.loads(command(['stats','--no-stream','--format','{{json .}}',args.container]))
        current = json.loads(command(['exec',args.container,'cat','/data/ready.json']))
        sample = {'seconds':round(time.monotonic()-started,2),'cpu_percent':float(stats['CPUPerc'].rstrip('%')),'memory_mib':memory_mib(stats['MemUsage']),'players':current.get('players',0),'ready':current.get('ready',False),'tick':current.get('tick',0),'performance':current.get('performance',{}),'voice_port':current.get('voice_port'),'voice_ready':current.get('voice_ready',False),'storage_error':current.get('storage_error','')}
        samples.append(sample)
        if not current.get('ready') or current.get('storage_error'):
            errors.append('Storage/readiness failed during measurement')
        if sample['players'] < args.expect_players:
            errors.append('Expected player count was lost during measurement')
        if args.bulk_save_every and time.monotonic() >= next_save:
            save_started = time.monotonic()
            try:
                result = json.loads(command(['exec',args.container,'python3','/app/admin.py','save']))
            except (RuntimeError,ValueError,subprocess.TimeoutExpired) as error:
                result = {'ok':False,'error':str(error)}
            saves.append({'seconds':round(time.monotonic()-started,2),'wall_ms':round((time.monotonic()-save_started)*1000,2),'ok':result.get('ok',False),'error':result.get('error','')})
            if not result.get('ok'):
                errors.append('Bulk checkpoint failed; no further durable stress requested')
                args.bulk_save_every = 0
            next_save = time.monotonic() + args.bulk_save_every
        time.sleep(.1)
    metrics = {}
    for sample in samples:
        for key, value in numeric_metrics(sample['performance']):
            metrics[key] = max(metrics.get(key,0),value)
    report = {'scope':'Measured fixture window only; no Internet/voice/combat matrix certification','image_id':config['Image'],'initial_health':ready,'limits':{'memory_bytes':config['HostConfig']['Memory'],'nano_cpus':config['HostConfig']['NanoCpus'],'read_only':config['HostConfig']['ReadonlyRootfs'],'user':config['Config']['User']},'duration_seconds':round(time.monotonic()-started,2),'expected_players':args.expect_players,'sample_count':len(samples),'summary':{'max_cpu_percent':max(s['cpu_percent'] for s in samples),'max_memory_mib':max(s['memory_mib'] for s in samples),'minimum_players':min(s['players'] for s in samples),'performance_max_across_windows':metrics},'bulk_saves':saves,'errors':sorted(set(errors)),'samples':samples}
    output = ROOT/'output/verification/hosting-load.json'
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({**report['summary'],'bulk_saves':len(saves),'errors':report['errors']},indent=2))
    print('Current report:',output)
    return 1 if errors or any(not s['ok'] for s in saves) else 0


if __name__ == '__main__':
    raise SystemExit(main())
