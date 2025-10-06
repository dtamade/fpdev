unit fpdev.hash;
{$CODEPAGE UTF8}
{$mode objfpc}{$H+}

interface

uses SysUtils, Classes;

function SHA256FileHex(const AFile: string): string;
function SHA256StreamHex(AStream: TStream): string;

implementation

type
  TSHA256Ctx = record
    state: array[0..7] of DWord;
    count: QWord; // bits
    buffer: array[0..63] of byte;
  end;

const
  K: array[0..63] of DWord = (
    $428a2f98,$71374491,$b5c0fbcf,$e9b5dba5,$3956c25b,$59f111f1,$923f82a4,$ab1c5ed5,
    $d807aa98,$12835b01,$243185be,$550c7dc3,$72be5d74,$80deb1fe,$9bdc06a7,$c19bf174,
    $e49b69c1,$efbe4786,$0fc19dc6,$240ca1cc,$2de92c6f,$4a7484aa,$5cb0a9dc,$76f988da,
    $983e5152,$a831c66d,$b00327c8,$bf597fc7,$c6e00bf3,$d5a79147,$06ca6351,$14292967,
    $27b70a85,$2e1b2138,$4d2c6dfc,$53380d13,$650a7354,$766a0abb,$81c2c92e,$92722c85,
    $a2bfe8a1,$a81a664b,$c24b8b70,$c76c51a3,$d192e819,$d6990624,$f40e3585,$106aa070,
    $19a4c116,$1e376c08,$2748774c,$34b0bcb5,$391c0cb3,$4ed8aa4a,$5b9cca4f,$682e6ff3,
    $748f82ee,$78a5636f,$84c87814,$8cc70208,$90befffa,$a4506ceb,$bef9a3f7,$c67178f2);

function ROR32(x: DWord; n: byte): DWord; inline;
begin Result := (x shr n) or (x shl (32-n)); end;
function Ch(x,y,z:DWord):DWord; inline; begin Result := (x and y) xor ((not x) and z); end;
function Maj(x,y,z:DWord):DWord; inline; begin Result := (x and y) xor (x and z) xor (y and z); end;
function BSIG0(x:DWord):DWord; inline; begin Result := ROR32(x,2) xor ROR32(x,13) xor ROR32(x,22); end;
function BSIG1(x:DWord):DWord; inline; begin Result := ROR32(x,6) xor ROR32(x,11) xor ROR32(x,25); end;
function SSIG0(x:DWord):DWord; inline; begin Result := ROR32(x,7) xor ROR32(x,18) xor (x shr 3); end;
function SSIG1(x:DWord):DWord; inline; begin Result := ROR32(x,17) xor ROR32(x,19) xor (x shr 10); end;

procedure sha256_transform(var ctx: TSHA256Ctx; const data: array of byte);
var w: array[0..63] of DWord; a,b,c,d,e,f,g,h,t1,t2: DWord; i: Integer;
begin
  // prepare message schedule
  for i:=0 to 15 do
    w[i] := (data[i*4] shl 24) or (data[i*4+1] shl 16) or (data[i*4+2] shl 8) or (data[i*4+3]);
  for i:=16 to 63 do
    w[i] := SSIG0(w[i-15]) + w[i-7] + SSIG1(w[i-2]) + w[i-16];
  // init working vars
  a:=ctx.state[0]; b:=ctx.state[1]; c:=ctx.state[2]; d:=ctx.state[3];
  e:=ctx.state[4]; f:=ctx.state[5]; g:=ctx.state[6]; h:=ctx.state[7];
  // rounds
  for i:=0 to 63 do begin
    t1 := h + BSIG1(e) + Ch(e,f,g) + K[i] + w[i];
    t2 := BSIG0(a) + Maj(a,b,c);
    h := g; g := f; f := e; e := d + t1;
    d := c; c := b; b := a; a := t1 + t2;
  end;
  // add to state
  ctx.state[0] := ctx.state[0] + a;
  ctx.state[1] := ctx.state[1] + b;
  ctx.state[2] := ctx.state[2] + c;
  ctx.state[3] := ctx.state[3] + d;
  ctx.state[4] := ctx.state[4] + e;
  ctx.state[5] := ctx.state[5] + f;
  ctx.state[6] := ctx.state[6] + g;
  ctx.state[7] := ctx.state[7] + h;
end;

procedure sha256_init(var ctx: TSHA256Ctx);
begin
  ctx.state[0]:=$6a09e667; ctx.state[1]:=$bb67ae85; ctx.state[2]:=$3c6ef372; ctx.state[3]:=$a54ff53a;
  ctx.state[4]:=$510e527f; ctx.state[5]:=$9b05688c; ctx.state[6]:=$1f83d9ab; ctx.state[7]:=$5be0cd19;
  ctx.count := 0;
end;

procedure sha256_update(var ctx: TSHA256Ctx; const data; len: SizeInt);
var
  i, idx, partLen: SizeInt;
  bytes: PByte;
  blk: array[0..63] of byte;
begin
  if len<=0 then Exit;
  bytes := @data;
  // number of bytes currently in buffer (before appending new data)
  idx := (ctx.count shr 3) and 63;
  ctx.count := ctx.count + QWord(len) * 8;
  partLen := 64 - idx;
  i := 0;

  // fill buffer to 64 bytes if there is pending data
  if idx <> 0 then
  begin
    if len < partLen then
    begin
      Move(bytes^, ctx.buffer[idx], len);
      Exit;
    end
    else
    begin
      Move(bytes^, ctx.buffer[idx], partLen);
      sha256_transform(ctx, ctx.buffer);
      i := partLen;
    end;
  end;

  // process full 64-byte blocks directly from input
  while (i + 63) < len do
  begin
    Move(PByte(bytes + i)^, blk[0], 64);
    sha256_transform(ctx, blk);
    i := i + 64;
  end;

  // copy remaining bytes into buffer
  if i < len then
  begin
    Move(PByte(bytes + i)^, ctx.buffer[0], len - i);
  end;
end;

procedure sha256_final(var ctx: TSHA256Ctx; out digest: array of byte);
var
  bits: array[0..7] of byte;
  idx, padLen: SizeInt;
  pad: array[0..63] of byte;
  i: Integer;
  beLen: QWord;
begin
  // length in bits big-endian
  beLen := ctx.count;
  bits[7] := byte(beLen and $FF); beLen := beLen shr 8;
  bits[6] := byte(beLen and $FF); beLen := beLen shr 8;
  bits[5] := byte(beLen and $FF); beLen := beLen shr 8;
  bits[4] := byte(beLen and $FF); beLen := beLen shr 8;
  bits[3] := byte(beLen and $FF); beLen := beLen shr 8;
  bits[2] := byte(beLen and $FF); beLen := beLen shr 8;
  bits[1] := byte(beLen and $FF); beLen := beLen shr 8;
  bits[0] := byte(beLen and $FF);

  // padding
  idx := (ctx.count shr 3) and 63;
  if idx < 56 then padLen := 56 - idx else padLen := 120 - idx;
  FillChar(pad, SizeOf(pad), 0);
  pad[0] := $80;
  sha256_update(ctx, pad, padLen);
  sha256_update(ctx, bits, 8);

  // output big-endian
  for i := 0 to 7 do begin
    digest[i*4+0] := (ctx.state[i] shr 24) and $FF;
    digest[i*4+1] := (ctx.state[i] shr 16) and $FF;
    digest[i*4+2] := (ctx.state[i] shr 8) and $FF;
    digest[i*4+3] := (ctx.state[i] and $FF);
  end;
end;

function BytesToHex(const buf: array of byte): string;
const HEX: PChar = '0123456789abcdef';
var i: Integer;
begin
  SetLength(Result, Length(buf)*2);
  for i := 0 to High(buf) do begin
    Result[i*2+1]   := HEX[(buf[i] shr 4) and $F];
    Result[i*2+2] := HEX[buf[i] and $F];
  end;
end;

function SHA256StreamHex(AStream: TStream): string;
var
  ctx: TSHA256Ctx;
  buf: array[0..8191] of byte;
  readn: Integer;
  dig: array[0..31] of byte;
begin
  sha256_init(ctx);
  repeat
    readn := AStream.Read(buf, SizeOf(buf));
    if readn > 0 then sha256_update(ctx, buf, readn);
  until readn = 0;
  sha256_final(ctx, dig);
  Result := BytesToHex(dig);
end;

function SHA256FileHex(const AFile: string): string;
var F: TFileStream;
begin
  Result := '';
  if (AFile='') or (not FileExists(AFile)) then Exit;
  F := TFileStream.Create(AFile, fmOpenRead or fmShareDenyWrite);
  try
    Result := SHA256StreamHex(F);
  finally
    F.Free;
  end;
end;

end.

