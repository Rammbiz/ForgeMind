"""APK Signature Scheme v2 signer (RSASSA-PKCS1-v1_5 / SHA-256).

apksig still ships on Maven Central, but its v1 signer reaches into
sun.security.pkcs, which JDK 21 no longer exports - so v1 comes from jarsigner
and v2 is produced here.  The result is checked against Google's own
ApkVerifier in the build, which validates digests and signatures end to end.

Format reference: https://source.android.com/docs/security/features/apksigning/v2
"""

import hashlib
import struct

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

APK_SIG_BLOCK_MAGIC = b"APK Sig Block 42"
V2_BLOCK_ID = 0x7109871A
SIG_ALG_RSA_PKCS1_SHA256 = 0x0103
CHUNK_SIZE = 1048576
EOCD_SIG = b"PK\x05\x06"


def _u32(v):
    return struct.pack("<I", v)


def _u64(v):
    return struct.pack("<Q", v)


def _lp(data):
    """uint32-length-prefixed blob."""
    return _u32(len(data)) + data


def _find_eocd(blob):
    # No zip comment is written by our packer, so the EOCD is the last 22 bytes,
    # but scan anyway to stay honest about other producers.
    start = max(0, len(blob) - 22 - 0xFFFF)
    idx = blob.rfind(EOCD_SIG, start)
    if idx < 0:
        raise ValueError("EOCD not found")
    return idx


def _sections(blob):
    eocd_off = _find_eocd(blob)
    cd_size, cd_off = struct.unpack("<II", blob[eocd_off + 12:eocd_off + 20])
    if cd_off + cd_size > eocd_off:
        raise ValueError("central directory overlaps EOCD")
    return blob[:cd_off], blob[cd_off:cd_off + cd_size], blob[eocd_off:], cd_off


def _chunk_digests(section, out):
    for off in range(0, len(section), CHUNK_SIZE):
        chunk = section[off:off + CHUNK_SIZE]
        h = hashlib.sha256()
        h.update(b"\xa5")
        h.update(_u32(len(chunk)))
        h.update(chunk)
        out.append(h.digest())


def apk_digest(entries, cd, eocd, cd_offset):
    """Top-level SHA-256 over the three signed sections, per the v2 spec."""
    # The EOCD is digested with its central-directory offset pointing at where
    # the signing block will start, which is exactly the current CD offset.
    eocd = bytearray(eocd)
    struct.pack_into("<I", eocd, 16, cd_offset)

    digests = []
    _chunk_digests(entries, digests)
    _chunk_digests(cd, digests)
    _chunk_digests(bytes(eocd), digests)

    top = hashlib.sha256()
    top.update(b"\x5a")
    top.update(_u32(len(digests)))
    for d in digests:
        top.update(d)
    return top.digest()


def build_v2_block(private_key, cert_der, digest):
    signed_data = (
        _lp(_lp(_u32(SIG_ALG_RSA_PKCS1_SHA256) + _lp(digest)))  # digests
        + _lp(_lp(cert_der))                                    # certificates
        + _lp(b"")                                              # attributes
    )
    signature = private_key.sign(signed_data, padding.PKCS1v15(), hashes.SHA256())
    public_key = private_key.public_key().public_bytes(
        serialization.Encoding.DER,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    signer = (
        _lp(signed_data)
        + _lp(_lp(_u32(SIG_ALG_RSA_PKCS1_SHA256) + _lp(signature)))
        + _lp(public_key)
    )
    v2_value = _lp(_lp(signer))  # sequence of signers

    pair = _u64(len(v2_value) + 4) + _u32(V2_BLOCK_ID) + v2_value
    body = pair
    size = len(body) + 8 + 16  # trailing size + magic
    return _u64(size) + body + _u64(size) + APK_SIG_BLOCK_MAGIC


def sign(path_in, path_out, private_key, cert_der):
    with open(path_in, "rb") as fh:
        blob = fh.read()
    entries, cd, eocd, cd_off = _sections(blob)
    digest = apk_digest(entries, cd, eocd, cd_off)
    block = build_v2_block(private_key, cert_der, digest)

    eocd = bytearray(eocd)
    struct.pack_into("<I", eocd, 16, cd_off + len(block))

    with open(path_out, "wb") as fh:
        fh.write(entries)
        fh.write(block)
        fh.write(cd)
        fh.write(bytes(eocd))
    return len(block)
