"""CC0 sword data from its creator's official OpenGameArt upload only."""
from collect_open_assets import SOURCE, INCOMING, download, scan, unpack, sha, write_json

DEST = SOURCE / 'quandtum-knights-trust'
URL = 'https://opengameart.org/sites/default/files/Quandtum_LongSword_KnightsTrust.zip'
PAGE = 'https://opengameart.org/content/long-sword-%E2%80%93-knights-trust'

if __name__ == '__main__':
    archive = INCOMING / 'quandtum-knights-trust.zip'
    record = download(URL, archive)
    scan(archive, 'beta-sword-archive')
    files, skipped = unpack(archive, DEST)
    scan(DEST, 'beta-sword-source')
    write_json(DEST / 'INTAKE.json', {
        'author': 'Quandtum', 'title': 'Long Sword – Knights Trust',
        'license': 'CC0-1.0', 'source': PAGE,
        'license_url': 'https://creativecommons.org/publicdomain/zero/1.0/',
        'download': record, 'files': [{'path': str(p.relative_to(DEST)), 'sha256': sha(p)} for p in files],
        'excluded': skipped, 'security': 'Defender archive and extracted-data scans found no threats; Blender autoexec disabled.',
    })
    (DEST / 'LICENSE.md').write_text('Long Sword – Knights Trust by Quandtum.\n\nCreator released the model and included texture maps under CC0 on OpenGameArt, December 4, 2012.\n\nSource: ' + PAGE + '\nLicense: https://creativecommons.org/publicdomain/zero/1.0/\n', encoding='utf-8')
    archive.unlink()
    print('Scanned source retained:', DEST)
    print('\n'.join(str(p.relative_to(DEST)) for p in files))
