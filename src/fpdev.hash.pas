unit fpdev.hash;

{$mode objfpc}{$H+}

interface

uses SysUtils, Classes;

function SHA256FileHex(const AFile: string): string;
function SHA256StreamHex(AStream: TStream): string;

function SHA512FileHex(const AFile: string): string;
function SHA512StreamHex(AStream: TStream): string;

implementation

type
  TSHA256Ctx = record
    state: array[0..7] of DWord;
    count: QWord; // bits
    buffer: array[0..63] of byte;
  end;

  TSHA512Ctx = record
    state: array[0..7] of QWord;
    count: array[0..1] of QWord; // bits (128-bit counter)
    buffer: array[0..127] of byte;
  end;

const
  K256: array[0..63] of DWord = (
    $428a2f98,$71374491,$b5c0fbcf,$e9b5dba5,$3956c25b,$59f111f1,$923f82a4,$ab1c5ed5,
    $d807aa98,$12835b01,$243185be,$550c7dc3,$72be5d74,$80deb1fe,$9bdc06a7,$c19bf174,
    $e49b69c1,$efbe4786,$0fc19dc6,$240ca1cc,$2de92c6f,$4a7484aa,$5cb0a9dc,$76f988da,
    $983e5152,$a831c66d,$b00327c8,$bf597fc7,$c6e00bf3,$d5a79147,$06ca6351,$14292967,
    $27b70a85,$2e1b2138,$4d2c6dfc,$53380d13,$650a7354,$766a0abb,$81c2c92e,$92722c85,
    $a2bfe8a1,$a81a664b,$c24b8b70,$c76c51a3,$d192e819,$d6990624,$f40e3585,$106aa070,
    $19a4c116,$1e376c08,$2748774c,$34b0bcb5,$391c0cb3,$4ed8aa4a,$5b9cca4f,$682e6ff3,
    $748f82ee,$78a5636f,$84c87814,$8cc70208,$90befffa,$a4506ceb,$bef9a3f7,$c67178f2);

  K512: array[0..79] of QWord = (
    QWord($428a2f98d728ae22), QWord($7137449123ef65cd), QWord($b5c0fbcfec4d3b2f), QWord($e9b5dba58189dbbc),
    QWord($3956c25bf348b538), QWord($59f111f1b605d019), QWord($923f82a4af194f9b), QWord($ab1c5ed5da6d8118),
    QWord($d807aa98a3030242), QWord($12835b0145706fbe), QWord($243185be4ee4b28c), QWord($550c7dc3d5ffb4e2),
    QWord($72be5d74f27b896f), QWord($80deb1fe3b1696b1), QWord($9bdc06a725c71235), QWord($c19bf174cf692694),
    QWord($e49b69c19ef14ad2), QWord($efbe4786384f25e3), QWord($0fc19dc68b8cd5b5), QWord($240ca1cc77ac9c65),
    QWord($2de92c6f592b0275), QWord($4a7484aa6ea6e483), QWord($5cb0a9dcbd41fbd4), QWord($76f988da831153b5),
    QWord($983e5152ee66dfab), QWord($a831c66d2db43210), QWord($b00327c898fb213f), QWord($bf597fc7beef0ee4),
    QWord($c6e00bf33da88fc2), QWord($d5a79147930aa725), QWord($06ca6351e003826f), QWord($142929670a0e6e70),
    QWord($27b70a8546d22ffc), QWord($2e1b21385c26c926), QWord($4d2c6dfc5ac42aed), QWord($53380d139d95b3df),
    QWord($650a73548baf63de), QWord($766a0abb3c77b2a8), QWord($81c2c92e47edaee6), QWord($92722c851482353b),
    QWord($a2bfe8a14cf10364), QWord($a81a664bbc423001), QWord($c24b8b70d0f89791), QWord($c76c51a30654be30),
    QWord($d192e819d6ef5218), QWord($d69906245565a910), QWord($f40e35855771202a), QWord($106aa07032bbd1b8),
    QWord($19a4c116b8d2d0c8), QWord($1e376c085141ab53), QWord($2748774cdf8eeb99), QWord($34b0bcb5e19b48a8),
    QWord($391c0cb3c5c95a63), QWord($4ed8aa4ae3418acb), QWord($5b9cca4f7763e373), QWord($682e6ff3d6b2b8a3),
    QWord($748f82ee5defb2fc), QWord($78a5636f43172f60), QWord($84c87814a1f0ab72), QWord($8cc702081a6439ec),
    QWord($90befffa23631e28), QWord($a4506cebde82bde9), QWord($bef9a3f7b2c67915), QWord($c67178f2e372532b),
    QWord($ca273eceea26619c), QWord($d186b8c721c0c207), QWord($eada7dd6cde0eb1e), QWord($f57d4f7fee6ed178),
    QWord($06f067aa72176fba), QWord($0a637dc5a2c898a6), QWord($113f9804bef90dae), QWord($1b710b35131c471b),
    QWord($28db77f523047d84), QWord($32caab7b40c72493), QWord($3c9ebe0a15c9bebc), QWord($431d67c49c100d4c),
    QWord($4cc5d4becb3e42b6), QWord($597f299cfc657e2a), QWord($5fcb6fab3ad6faec), QWord($6c44198c4a475817));

{ SHA256 helper functions }
function ROR32(x: DWord; n: byte): DWord; inline;
begin Result := (x shr n) or (x shl (32-n)); end;
function Ch(x,y,z:DWord):DWord; inline; begin Result := (x and y) xor ((not x) and z); end;
function Maj(x,y,z:DWord):DWord; inline; begin Result := (x and y) xor (x and z) xor (y and z); end;
function BSIG0(x:DWord):DWord; inline; begin Result := ROR32(x,2) xor ROR32(x,13) xor ROR32(x,22); end;
function BSIG1(x:DWord):DWord; inline; begin Result := ROR32(x,6) xor ROR32(x,11) xor ROR32(x,25); end;
function SSIG0(x:DWord):DWord; inline; begin Result := ROR32(x,7) xor ROR32(x,18) xor (x shr 3); end;
function SSIG1(x:DWord):DWord; inline; begin Result := ROR32(x,17) xor ROR32(x,19) xor (x shr 10); end;

{ SHA512 helper functions }
function ROR64(x: QWord; n: byte): QWord; inline;
begin Result := (x shr n) or (x shl (64-n)); end;
function Ch64(x,y,z:QWord):QWord; inline; begin Result := (x and y) xor ((not x) and z); end;
function Maj64(x,y,z:QWord):QWord; inline; begin Result := (x and y) xor (x and z) xor (y and z); end;
function BSIG0_512(x:QWord):QWord; inline; begin Result := ROR64(x,28) xor ROR64(x,34) xor ROR64(x,39); end;
function BSIG1_512(x:QWord):QWord; inline; begin Result := ROR64(x,14) xor ROR64(x,18) xor ROR64(x,41); end;
function SSIG0_512(x:QWord):QWord; inline; begin Result := ROR64(x,1) xor ROR64(x,8) xor (x shr 7); end;
function SSIG1_512(x:QWord):QWord; inline; begin Result := ROR64(x,19) xor ROR64(x,61) xor (x shr 6); end;

{ SHA256 implementation }

procedure sha256_transform(var ctx: TSHA256Ctx; const data: array of byte);
var w: array[0..63] of DWord; a,b,c,d,e,f,g,h,t1,t2: DWord; i: Integer;
begin
  {$Q-} {$R-} // Disable overflow and range checking for SHA256 arithmetic
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
    t1 := h + BSIG1(e) + Ch(e,f,g) + K256[i] + w[i];
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

{ SHA512 implementation }

procedure sha512_transform(var ctx: TSHA512Ctx; const data: array of byte);
var w: array[0..79] of QWord; a,b,c,d,e,f,g,h,t1,t2: QWord; i: Integer;
begin
  {$Q-} {$R-} // Disable overflow and range checking for SHA512 arithmetic
  // prepare message schedule
  for i:=0 to 15 do
    w[i] := (QWord(data[i*8]) shl 56) or (QWord(data[i*8+1]) shl 48) or
            (QWord(data[i*8+2]) shl 40) or (QWord(data[i*8+3]) shl 32) or
            (QWord(data[i*8+4]) shl 24) or (QWord(data[i*8+5]) shl 16) or
            (QWord(data[i*8+6]) shl 8) or QWord(data[i*8+7]);
  for i:=16 to 79 do
    w[i] := SSIG1_512(w[i-2]) + w[i-7] + SSIG0_512(w[i-15]) + w[i-16];
  // init working vars
  a:=ctx.state[0]; b:=ctx.state[1]; c:=ctx.state[2]; d:=ctx.state[3];
  e:=ctx.state[4]; f:=ctx.state[5]; g:=ctx.state[6]; h:=ctx.state[7];
  // rounds
  for i:=0 to 79 do begin
    t1 := h + BSIG1_512(e) + Ch64(e,f,g) + K512[i] + w[i];
    t2 := BSIG0_512(a) + Maj64(a,b,c);
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
  {$Q+} {$R+} // Re-enable overflow and range checking
end;

procedure sha256_init(var ctx: TSHA256Ctx);
begin
  ctx.state[0]:=$6a09e667; ctx.state[1]:=$bb67ae85; ctx.state[2]:=$3c6ef372; ctx.state[3]:=$a54ff53a;
  ctx.state[4]:=$510e527f; ctx.state[5]:=$9b05688c; ctx.state[6]:=$1f83d9ab; ctx.state[7]:=$5be0cd19;
  ctx.count := 0;
  FillChar(ctx.buffer[0], SizeOf(ctx.buffer), 0);
end;

procedure sha512_init(var ctx: TSHA512Ctx);
begin
  ctx.state[0]:=QWord($6a09e667f3bcc908); ctx.state[1]:=QWord($bb67ae8584caa73b);
  ctx.state[2]:=QWord($3c6ef372fe94f82b); ctx.state[3]:=QWord($a54ff53a5f1d36f1);
  ctx.state[4]:=QWord($510e527fade682d1); ctx.state[5]:=QWord($9b05688c2b3e6c1f);
  ctx.state[6]:=QWord($1f83d9abfb41bd6b); ctx.state[7]:=QWord($5be0cd19137e2179);
  ctx.count[0] := 0;
  ctx.count[1] := 0;
  FillChar(ctx.buffer[0], SizeOf(ctx.buffer), 0);
end;

procedure sha256_update(var ctx: TSHA256Ctx; const data; len: SizeInt);
var
  i, idx, partLen: SizeInt;
  bytes: PByte;
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
    Move(PByte(bytes + i)^, ctx.buffer[0], 64);
    sha256_transform(ctx, ctx.buffer);
    i := i + 64;
  end;

  // copy remaining bytes into buffer
  if i < len then
  begin
    Move(PByte(bytes + i)^, ctx.buffer[0], len - i);
  end;
end;

procedure sha512_update(var ctx: TSHA512Ctx; const data; len: SizeInt);
var
  i, idx, partLen: SizeInt;
  bytes: PByte;
  bitlen: QWord;
begin
  if len<=0 then Exit;
  bytes := @data;
  bitlen := QWord(len) * 8;

  // number of bytes currently in buffer
  idx := (ctx.count[0] shr 3) and 127;

  // Update bit count (128-bit counter)
  ctx.count[0] := ctx.count[0] + bitlen;
  if ctx.count[0] < bitlen then
    ctx.count[1] := ctx.count[1] + 1;

  partLen := 128 - idx;
  i := 0;

  // fill buffer to 128 bytes if there is pending data
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
      sha512_transform(ctx, ctx.buffer);
      i := partLen;
    end;
  end;

  // process full 128-byte blocks directly from input
  while (i + 127) < len do
  begin
    Move(PByte(bytes + i)^, ctx.buffer[0], 128);
    sha512_transform(ctx, ctx.buffer);
    i := i + 128;
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
  pad: array of byte;
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
  // bits[0] is always set, no need for additional check

  // padding
  idx := (ctx.count shr 3) and 63;
  if idx < 56 then padLen := 56 - idx else padLen := 120 - idx;
  pad := nil;
  SetLength(pad, 64);
  FillChar(pad[0], Length(pad), 0);
  pad[0] := $80;
  sha256_update(ctx, pad[0], padLen);
  sha256_update(ctx, bits, 8);

  // output big-endian
  for i := 0 to 7 do begin
    digest[i*4+0] := (ctx.state[i] shr 24) and $FF;
    digest[i*4+1] := (ctx.state[i] shr 16) and $FF;
    digest[i*4+2] := (ctx.state[i] shr 8) and $FF;
    digest[i*4+3] := (ctx.state[i] and $FF);
  end;
end;

procedure sha512_final(var ctx: TSHA512Ctx; out digest: array of byte);
var
  bits: array[0..15] of byte;
  idx, padLen: SizeInt;
  pad: array of byte;
  i: Integer;
  beLen: QWord;
begin
  // length in bits big-endian (128-bit)
  // High 64 bits first (ctx.count[1])
  beLen := ctx.count[1];
  for i := 7 downto 0 do
  begin
    bits[i] := byte(beLen and $FF);
    beLen := beLen shr 8;
  end;
  // Low 64 bits second (ctx.count[0])
  beLen := ctx.count[0];
  for i := 15 downto 8 do
  begin
    bits[i] := byte(beLen and $FF);
    beLen := beLen shr 8;
  end;

  // padding
  idx := (ctx.count[0] shr 3) and 127;
  if idx < 112 then padLen := 112 - idx else padLen := 240 - idx;
  pad := nil;
  SetLength(pad, 128);
  FillChar(pad[0], Length(pad), 0);
  pad[0] := $80;
  sha512_update(ctx, pad[0], padLen);
  sha512_update(ctx, bits, 16);

  // output big-endian
  for i := 0 to 7 do begin
    digest[i*8+0] := (ctx.state[i] shr 56) and $FF;
    digest[i*8+1] := (ctx.state[i] shr 48) and $FF;
    digest[i*8+2] := (ctx.state[i] shr 40) and $FF;
    digest[i*8+3] := (ctx.state[i] shr 32) and $FF;
    digest[i*8+4] := (ctx.state[i] shr 24) and $FF;
    digest[i*8+5] := (ctx.state[i] shr 16) and $FF;
    digest[i*8+6] := (ctx.state[i] shr 8) and $FF;
    digest[i*8+7] := (ctx.state[i] and $FF);
  end;
end;

function BytesToHex(const buf: array of byte): string;
const HEX: PChar = '0123456789abcdef';
var i: Integer;
begin
  Result := '';
  SetLength(Result, Length(buf)*2);
  for i := 0 to High(buf) do begin
    Result[i*2+1]   := HEX[(buf[i] shr 4) and $F];
    Result[i*2+2] := HEX[buf[i] and $F];
  end;
end;

function SHA256StreamHex(AStream: TStream): string;
var
  ctx: TSHA256Ctx;
  buf: array of byte;
  readn: Integer;
  dig: array[0..31] of byte;
begin
  ctx := Default(TSHA256Ctx);
  buf := nil;
  SetLength(buf, 8192);
  sha256_init(ctx);
  repeat
    readn := AStream.Read(buf[0], Length(buf));
    if readn > 0 then sha256_update(ctx, buf[0], readn);
  until readn = 0;
  sha256_final(ctx, dig);
  Result := BytesToHex(dig);
end;

function SHA512StreamHex(AStream: TStream): string;
var
  ctx: TSHA512Ctx;
  buf: array of byte;
  readn: Integer;
  dig: array[0..63] of byte;
begin
  ctx := Default(TSHA512Ctx);
  buf := nil;
  SetLength(buf, 8192);
  sha512_init(ctx);
  repeat
    readn := AStream.Read(buf[0], Length(buf));
    if readn > 0 then sha512_update(ctx, buf[0], readn);
  until readn = 0;
  sha512_final(ctx, dig);
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

function SHA512FileHex(const AFile: string): string;
var F: TFileStream;
begin
  Result := '';
  if (AFile='') or (not FileExists(AFile)) then Exit;
  F := TFileStream.Create(AFile, fmOpenRead or fmShareDenyWrite);
  try
    Result := SHA512StreamHex(F);
  finally
    F.Free;
  end;
end;

end.

