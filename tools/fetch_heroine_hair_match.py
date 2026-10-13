"""Read only selected CC0 mesh/data assets from the official remote ZIP."""
import io,urllib.request,zipfile,pathlib,json,hashlib
URL='https://files2.makehumancommunity.org/asset_packs/hair01/hair01_cc0.zip'
ROOT=pathlib.Path(r'C:\Games\CoastalFoundation\art\source\heroine-hair-study')
class Remote(io.RawIOBase):
    def __init__(self):
        self.size=int(urllib.request.urlopen(urllib.request.Request(URL,method='HEAD'),timeout=30).headers['Content-Length']);self.pos=0
    def seekable(self):return True
    def readable(self):return True
    def tell(self):return self.pos
    def seek(self,off,whence=0):
        self.pos=off if whence==0 else self.pos+off if whence==1 else self.size+off
        return self.pos
    def read(self,n=-1):
        if n<0:n=self.size-self.pos
        if not n:return b''
        end=min(self.size-1,self.pos+n-1)
        req=urllib.request.Request(URL,headers={'Range':f'bytes={self.pos}-{end}'})
        with urllib.request.urlopen(req,timeout=60) as response:
            assert response.status==206,'Server did not honor requested byte range'
            result=response.read()
        self.pos+=len(result);return result
ROOT.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(Remote()) as archive:
    chosen=[x for x in archive.infolist() if not x.is_dir() and ('/sonntag78_junglebook_hair/' in '/'+x.filename or '/toigo_blunt_bob_with_bangs/' in '/'+x.filename or x.filename=='packs/hair01.json')]
    assert chosen,'Hair asset names absent'
    files=[]
    for member in chosen:
        target=(ROOT/member.filename).resolve();assert ROOT.resolve() in target.parents
        assert target.suffix.lower() in ['.json','.obj','.mhclo','.mhmat','.png','.thumb','.jpg']
        data=archive.read(member);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
        files.append({'path':str(target.relative_to(ROOT)),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
    (ROOT/'intake.json').write_text(json.dumps({'source':URL,'publisher':'MakeHuman Community','license':'CC0 per official pack catalog; headers checked separately','files':files,'method':'CRC-verified selected ZIP entries via HTTPS byte ranges; no scripts'},indent=2))
    print(json.dumps({'files':len(files),'bytes':sum(x['bytes'] for x in files)},indent=2))

