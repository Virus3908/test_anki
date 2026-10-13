#!/usr/bin/env python3
"""Fetch the exact pinned official batch. Writes only to a caller-selected staging directory."""
import argparse
import hashlib
import json
import urllib.request
from pathlib import Path


def download(destination):
    pin = json.loads(Path(__file__).with_name('snapshot.json').read_text())
    destination.mkdir(parents=True, exist_ok=True)
    for record in pin['files']:
        path = destination / record['name']
        digest = hashlib.sha256()
        with urllib.request.urlopen(record['url']) as response, path.open('wb') as output:
            modified = response.headers.get('Last-Modified')
            if modified != record['lastModified']:
                raise ValueError('Official export changed. Re-pin and review a new batch explicitly.')
            while chunk := response.read(1024 * 1024):
                output.write(chunk); digest.update(chunk)
        if path.stat().st_size != record['bytes'] or digest.hexdigest() != record['sha256']:
            raise ValueError('Export does not match pinned snapshot: ' + record['name'])
        Path(str(path) + '.headers').write_text('last-modified: ' + record['lastModified'] + '\n')
        print(record['name'], record['sha256'])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--destination', required=True)
    download(Path(parser.parse_args().destination))
