{$I ..\DelphiVersions.Inc}
unit Amazon.Utils;

interface

uses Classes,

{$IFDEF DELPHIXE8_UP}
  System.Hash,
  System.JSON,
{$ENDIF}
{$IFNDEF FPC}
  System.SysUtils,
  System.DateUtils,
  Soap.XSBuiltIns,
  Data.DBXJSONReflect,
  Data.DBXJSON,
{$ELSE}
   SysUtils,
   DateUtils,

{$ENDIF}
  IdDateTimeStamp,
  idGlobal,
  IdHMACSHA1, IdSSLOpenSSL, IdHashSHA, IdHashMessageDigest, idHash;





//function DateTimeToISO8601(const aDateTime: TDateTime): string;
procedure GetAWSDate_Stamp(const aDateTime: TDateTime;
  var aamz_date, adate_stamp: UTF8String);
function UTCNow: TDateTime;


{$IFDEF DELPHIXE8_UP}
function HmacSHA256Ex(const AKey: TBytes; aStr: UTF8String): TBytes;
{$ELSE}
function HmacSHA256Ex(const AKey: TidBytes; aStr: UTF8String): TidBytes;
{$ENDIF}

function BytesToHex(const Bytes: array of byte): string;
function HexToBytes(const S: String): TidBytes;
function HashSHA256(aStr: String): String;
function GetAWSUserDir: UTF8String;
function GetAWSHost(aendpoint: UTF8String): UTF8String;
function DoubleQuotedStr(const S: UTF8String): UTF8String;
// function DeepCopy(aValue: TObject): TObject;

implementation

function DoubleQuotedStr(const S: UTF8String): UTF8String;
begin
  Result := S;
  Result := '"' + Result + '"';
end;


(*


function DateTimeToISO8601(const aDateTime: TDateTime): string;
Var
  D: TXSDateTime;
  Year, Month, Day: Word;
  Hour, Min, Sec, MSec: Word;
  FDateTime: TDateTime;
begin
  DecodeDate(aDateTime, Year, Month, Day);
  DecodeTime(aDateTime, Hour, Min, Sec, MSec);

  FDateTime := EncodeDateTime(Year, Month, Day, Hour, Min, Sec, MSec);

  D := TXSDateTime.Create;
  D.AsDateTime := FDateTime;

  Result := D.NativeToXS;

  D.Free;
end;
*)

// http://docs.aws.amazon.com/general/latest/gr/sigv4-date-handling.html

procedure GetAWSDate_Stamp(const aDateTime: TDateTime;
  var aamz_date, adate_stamp: UTF8String);
begin
  aamz_date := FormatDateTime('YYYYMMDD"T"HHMMSS"Z"', aDateTime);

  adate_stamp := FormatDateTime('YYYYMMDD', aDateTime);
end;

function UTCNow: TDateTime;
begin
  {$IFNDEF FPC}
  Result := TTimeZone.Local.ToUniversalTime(Now);
  {$ELSE}
  Result := LocalTimeToUniversal(Now);
  {$ENDIF}
end;


{$IFDEF DELPHIXE8_UP}
function HmacSHA256Ex(const AKey: TBytes; aStr: UTF8String): TBytes;
Var
  FHash: THashSHA2;
  FData: TBytes;
begin
  FHash := THashSHA2.Create(SHA256);
  FData := BytesOf(aStr);
  Result := FHash.GetHMACAsBytes(FData, aKey, SHA256);
end;
{$ELSE}
function HmacSHA256Ex(const AKey: TidBytes; aStr: UTF8String): TidBytes;
Var
  FHMACSHA256: TIdHMACSHA256;
begin
  if not IdSSLOpenSSL.LoadOpenSSLLibrary then
    Exit;

  FHMACSHA256 := TIdHMACSHA256.Create;
  try
    FHMACSHA256.Key := AKey;

    Result := FHMACSHA256.HashValue(ToBytes(aStr));
  finally
    FHMACSHA256.Free;
  end;
end;
{$ENDIF}


function BytesToHex(const Bytes: array of byte): string;
const
  HexSymbols = '0123456789ABCDEF';
var
  i: integer;
  lsOutput: String;
begin
  SetLength(lsOutput, 2 * Length(Bytes));
  for i := 0 to Length(Bytes) - 1 do
  begin
    lsOutput[1 + 2 * i + 0] := HexSymbols[1 + Bytes[i] shr 4];
    lsOutput[1 + 2 * i + 1] := HexSymbols[1 + Bytes[i] and $0F];
  end;

  Result := Lowercase(lsOutput);
end;

function HexToBytes(const S: String): TidBytes;
begin
  SetLength(Result, Length(S) div 2);
  SetLength(Result, HexToBin(PChar(S), Pointer(Result), Length(Result)));
end;

{$IFDEF DELPHIXE8_UP}
function HashSHA256(aStr: String): String;
var
  FHash: THashSHA2;
  LBytes: TArray<Byte>;
  FBuffer: PByte;
  BufLen: Integer;
  Readed: Integer;
  FStream: TStringStream;
begin
  BufLen := Length(aStr) * (4 * 1024);

  FBuffer  := AllocMem(BufLen);
  FHash    := THashSHA2.Create;
  FStream := TStringStream.Create(aStr);
  try
    while FStream.Position < FStream.Size do
    begin
      Readed := FStream.Read(FBuffer^, BufLen);
      if Readed > 0 then
        FHash.update(FBuffer^, Readed);
    end;
  finally
    FStream.Free;
    FreeMem(FBuffer);
  end;

  Result := FHash.HashAsString;
end;
{$ELSE}
function HashSHA256(aStr: String): String;
var
  FHashSHA256: TIdHashSHA256;
begin

  if not IdSSLOpenSSL.LoadOpenSSLLibrary then
    Exit;

  FHashSHA256 := TIdHashSHA256.Create;
  try
    Result := Lowercase(FHashSHA256.HashStringAsHex(UTF8String(aStr)));
  finally
    FHashSHA256.Free;
  end;
end;
{$ENDIF}


function GetAWSUserDir: UTF8String;
begin
  Result := GetEnvironmentVariable('USERPROFILE') + '\.aws';

  if Not DirectoryExists(Result) then
    Result := '';

end;

function GetAWSHost(aendpoint: UTF8String): UTF8String;
var
  fsnewhost: UTF8String;
begin
  fsnewhost := StringReplace(aendpoint, 'http://', '',
    [rfReplaceAll, rfIgnoreCase]);

  fsnewhost := StringReplace(fsnewhost, 'https://', '',
    [rfReplaceAll, rfIgnoreCase]);

  Result := StringReplace(fsnewhost, '/', '', [rfReplaceAll, rfIgnoreCase]);

end;

(*
function DeepCopy(aValue: TObject): TObject;
var
  MarshalObj: TJSONMarshal;
  UnMarshalObj: TJSONUnMarshal;
  JSONValue: TJSONValue;
begin
  Result := nil;
  MarshalObj := TJSONMarshal.Create;
  UnMarshalObj := TJSONUnMarshal.Create;
  try
    JSONValue := MarshalObj.Marshal(aValue);
    try
      if Assigned(JSONValue) then
        Result := UnMarshalObj.Unmarshal(JSONValue);
    finally
      JSONValue.Free;
    end;
  finally
    MarshalObj.Free;
    UnMarshalObj.Free;
  end;
end;
*)

end.
