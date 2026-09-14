import json
import struct
import subprocess
import sys

host = sys.argv[1]
origin = 'chrome-extension://dibbmpledhimhagdgbebcjbphdikbcck/'
def call(data, caller=origin):
    result = subprocess.run([host, caller], input=data, capture_output=True, timeout=15, check=True)
    assert len(result.stdout) >= 4
    length, = struct.unpack('<I', result.stdout[:4])
    assert length == len(result.stdout) - 4
    return json.loads(result.stdout[4:])
def frame(value):
    data = json.dumps(value).encode()
    return struct.pack('<I', len(data)) + data
valid = frame({'method': 'status', 'url': 'https://example.com'})
assert call(valid)['ok'] is True
assert call(valid, 'chrome-extension://untrusted/')['ok'] is False
assert call(struct.pack('<I', 32769))['ok'] is False
assert call(b'\x02\x00')['ok'] is False
assert call(frame({'method': 'delete', 'url': 'https://example.com'}))['ok'] is False
assert call(frame({'method': 'status', 'url': 'file:///tmp/test'}))['ok'] is False
print('PASS: native framing, origin, bounds and methods')
