{==============================================================================|
| Project : Delphree - Synapse                                   | 002.011.001 |
|==============================================================================|
| Content: support procedures and functions                                    |
|==============================================================================|
| The contents of this file are subject to the Mozilla Public License Ver. 1.1 |
| (the "License"); you may not use this file except in compliance with the     |
| License. You may obtain a Copy of the License at http://www.mozilla.org/MPL/ |
|                                                                              |
| Software distributed under the License is distributed on an "AS IS" basis,   |
| WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for |
| the specific language governing rights and limitations under the License.    |
|==============================================================================|
| The Original Code is Synapse Delphi Library.                                 |
|==============================================================================|
| The Initial Developer of the Original Code is Lukas Gebauer (Czech Republic).|
| Portions created by Lukas Gebauer are Copyright (c) 1999-2002.               |
| Portions created by Hernan Sanchez are Copyright (c) 2000.                   |
| All Rights Reserved.                                                         |
|==============================================================================|
| Contributor(s):                                                              |
|   Hernan Sanchez (hernan.sanchez@iname.com)                                  |
|==============================================================================|
| History: see HISTORY.HTM from distribution package                           |
|          (Found at URL: http://www.ararat.cz/synapse/)                       |
|==============================================================================}

{$Q-}

unit SynaUtil;

interface

uses
  SysUtils, Classes,
{$IFDEF LINUX}
  Libc;
{$ELSE}
  Windows;
{$ENDIF}

function TimeZoneBias: integer;
function TimeZone: string;
function Rfc822DateTime(t: TDateTime): string;
function CDateTime(t: TDateTime): string;
function SimpleDateTime(t: TDateTime): string;
function AnsiCDateTime(t: TDateTime): string;
function GetMonthNumber(Value: string): integer;
function GetTimeFromStr(Value: string): TDateTime;
function GetDateMDYFromStr(Value: string): TDateTime;
function DecodeRfcDateTime(Value: string): TDateTime;
function GetUTTime: TDateTime;
function SetUTTime(Newdt: TDateTime): Boolean;
function GetTick: Cardinal;
function CodeInt(Value: Word): string;
function DecodeInt(const Value: string; Index: Integer): Word;
function IsIP(const Value: string): Boolean;
function ReverseIP(Value: string): string;
function IPToID(Host: string): string;
procedure Dump(const Buffer, DumpFile: string);
procedure DumpEx(const Buffer, DumpFile: string);
function SeparateLeft(const Value, Delimiter: string): string;
function SeparateRight(const Value, Delimiter: string): string;
function GetParameter(const Value, Parameter: string): string;
function GetEmailAddr(const Value: string): string;
function GetEmailDesc(Value: string): string;
function StrToHex(const Value: string): string;
function IntToBin(Value: Integer; Digits: Byte): string;
function BinToInt(const Value: string): Integer;
function ParseURL(URL: string; var Prot, User, Pass, Host, Port, Path,
  Para: string): string;
function StringReplace(Value, Search, Replace: string): string;
function RPosEx(const Sub, Value: string; From: integer): Integer;
function RPos(const Sub, Value: String): Integer;
function Fetch(var Value: string; const Delimiter: string): string;

implementation
{==============================================================================}
var
  SaveDayNames: array[1..7] of string;
  SaveMonthNames: array[1..12] of string;
const
  MyDayNames: array[1..7] of string =
  ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  MyMonthNames: array[1..12] of string =
  ('Jan', 'Feb', 'Mar', 'Apr',
    'May', 'Jun', 'Jul', 'Aug',
    'Sep', 'Oct', 'Nov', 'Dec');

procedure SaveNames;
var
  I: integer;
begin
  for I := Low(ShortDayNames) to High(ShortDayNames) do
  begin
    SaveDayNames[I] := ShortDayNames[I];
    ShortDayNames[I] := MyDayNames[I];
  end;
  for I := Low(ShortMonthNames) to High(ShortMonthNames) do
  begin
    SaveMonthNames[I] := ShortMonthNames[I];
    ShortMonthNames[I] := MyMonthNames[I];
  end;
end;

procedure RestoreNames;
var
  I: integer;
begin
  for I := Low(ShortDayNames) to High(ShortDayNames) do
    ShortDayNames[I] := SaveDayNames[I];
  for I := Low(ShortMonthNames) to High(ShortMonthNames) do
    ShortMonthNames[I] := SaveMonthNames[I];
end;
{==============================================================================}

function TimeZoneBias: integer;
{$IFDEF LINUX}
var
  t: TTime_T;
  UT: TUnixTime;
begin
  __time(@T);
  localtime_r(@T, UT);
  Result := ut.__tm_gmtoff div 60;
{$ELSE}
var
  zoneinfo: TTimeZoneInformation;
  bias: Integer;
begin
  case GetTimeZoneInformation(Zoneinfo) of
    2:
      bias := zoneinfo.Bias + zoneinfo.DaylightBias;
    1:
      bias := zoneinfo.Bias + zoneinfo.StandardBias;
  else
    bias := zoneinfo.Bias;
  end;
  Result := bias * (-1);
{$ENDIF}
end;

{==============================================================================}

function TimeZone: string;
var
  bias: Integer;
  h, m: Integer;
begin
  bias := TimeZoneBias;
  if bias >= 0 then
    Result := '+'
  else
    Result := '-';
  bias := Abs(bias);
  h := bias div 60;
  m := bias mod 60;
  Result := Result + Format('%.2d%.2d', [h, m]);
end;

{==============================================================================}

function Rfc822DateTime(t: TDateTime): string;
begin
  SaveNames;
  try
    Result := FormatDateTime('ddd, d mmm yyyy hh:nn:ss', t);
    Result := Result + ' ' + Timezone;
  finally
    RestoreNames;
  end;
end;

{==============================================================================}

function CDateTime(t: TDateTime): string;
begin
  SaveNames;
  try
    Result := FormatDateTime('mmm dd hh:nn:ss', t);
    if Result[5] = '0' then
      Result[5] := ' ';
  finally
    RestoreNames;
  end;
end;

{==============================================================================}

function SimpleDateTime(t: TDateTime): string;
begin
  SaveNames;
  try
    Result := FormatDateTime('yymmdd hhnnss', t);
  finally
    RestoreNames;
  end;
end;

{==============================================================================}

function AnsiCDateTime(t: TDateTime): string;
begin
  SaveNames;
  try
    Result := FormatDateTime('ddd mmm d hh:nn:ss yyyy', t);
  finally
    RestoreNames;
  end;
end;

{==============================================================================}

function DecodeTimeZone(Value: string; var Zone: integer): Boolean;
var
  x: integer;
  zh, zm: integer;
  s: string;
begin
  Result := false;
  s := Value;
  if (Pos('+', s) = 1) or (Pos('-',s) = 1) then
  begin
    if s = '-0000' then
      Zone := TimeZoneBias
    else
      if Length(s) > 4 then
      begin
        zh := StrToIntdef(s[2] + s[3], 0);
        zm := StrToIntdef(s[4] + s[5], 0);
        zone := zh * 60 + zm;
        if s[1] = '-' then
          zone := zone * (-1);
      end;
    Result := True;
  end
  else
  begin
    x := 32767;
    if s = 'NZDT' then x := 13;
    if s = 'IDLE' then x := 12;
    if s = 'NZST' then x := 12;
    if s = 'NZT' then x := 12;
    if s = 'EADT' then x := 11;
    if s = 'GST' then x := 10;
    if s = 'JST' then x := 9;
    if s = 'CCT' then x := 8;
    if s = 'WADT' then x := 8;
    if s = 'WAST' then x := 7;
    if s = 'ZP6' then x := 6;
    if s = 'ZP5' then x := 5;
    if s = 'ZP4' then x := 4;
    if s = 'BT' then x := 3;
    if s = 'EET' then x := 2;
    if s = 'MEST' then x := 2;
    if s = 'MESZ' then x := 2;
    if s = 'SST' then x := 2;
    if s = 'FST' then x := 2;
    if s = 'CEST' then x := 2;
    if s = 'CET' then x := 1;
    if s = 'FWT' then x := 1;
    if s = 'MET' then x := 1;
    if s = 'MEWT' then x := 1;
    if s = 'SWT' then x := 1;
    if s = 'UT' then x := 0;
    if s = 'UTC' then x := 0;
    if s = 'GMT' then x := 0;
    if s = 'WET' then x := 0;
    if s = 'WAT' then x := -1;
    if s = 'BST' then x := -1;
    if s = 'AT' then x := -2;
    if s = 'ADT' then x := -3;
    if s = 'AST' then x := -4;
    if s = 'EDT' then x := -4;
    if s = 'EST' then x := -5;
    if s = 'CDT' then x := -5;
    if s = 'CST' then x := -6;
    if s = 'MDT' then x := -6;
    if s = 'MST' then x := -7;
    if s = 'PDT' then x := -7;
    if s = 'PST' then x := -8;
    if s = 'YDT' then x := -8;
    if s = 'YST' then x := -9;
    if s = 'HDT' then x := -9;
    if s = 'AHST' then x := -10;
    if s = 'CAT' then x := -10;
    if s = 'HST' then x := -10;
    if s = 'EAST' then x := -10;
    if s = 'NT' then x := -11;
    if s = 'IDLW' then x := -12;
    if x <> 32767 then
    begin
      zone := x * 60;
      Result := True;
    end;
  end;
end;

{==============================================================================}

function GetMonthNumber(Value: string): integer;
var
  n: integer;
begin
  Result := 0;
  Value := Uppercase(Value);
  for n := 1 to 12 do
    if Value = uppercase(MyMonthNames[n]) then
    begin
      Result := n;
      Break;
    end;
end;

{==============================================================================}

function GetTimeFromStr(Value: string): TDateTime;
var
  SaveSeparator: char;
begin
  SaveSeparator := TimeSeparator;
  try
    TimeSeparator := ':';
    Result := 0;
    try
      Result := StrToTime(Value);
    except
      on Exception do ;
    end;
  finally
    TimeSeparator := SaveSeparator;
  end;
end;

{==============================================================================}

function GetDateMDYFromStr(Value: string): TDateTime;
var
  SaveSeparator: char;
  SaveFormat: string;
begin
  SaveSeparator := DateSeparator;
  SaveFormat := ShortDateFormat;
  try
    DateSeparator := '-';
    ShortDateFormat := 'm-d-y';
    Result := 0;
    try
      Result := StrToDate(Value);
    except
      on Exception do ;
    end;
  finally
    ShortDateFormat := SaveFormat;
    DateSeparator := SaveSeparator;
  end;
end;

{==============================================================================}

function DecodeRfcDateTime(Value: string): TDateTime;
var
  day, month, year: Word;
  zone: integer;
  x: integer;
  s: string;
  t: TDateTime;
begin
// ddd, d mmm yyyy hh:mm:ss
// ddd, d mmm yy hh:mm:ss
// ddd, mmm d yyyy hh:mm:ss
// ddd mmm dd hh:mm:ss yyyy
// Sun, 06 Nov 1994 08:49:37 GMT    ; RFC 822, updated by RFC 1123
// Sunday, 06-Nov-94 08:49:37 GMT   ; RFC 850, obsoleted by RFC 1036
// Sun Nov  6 08:49:37 1994         ; ANSI C's asctime() Format

  Result := 0;
  if Value = '' then
    Exit;
  day := 0;
  month := 0;
  year := 0;
  zone := 0;
  Value := StringReplace(Value, ' -', ' #');
  Value := StringReplace(Value, '-', ' ');
  Value := StringReplace(Value, ' #', ' -');
  while Value <> '' do
  begin
    s := Fetch(Value, ' ');
    s := uppercase(s);
    // timezone
    if DecodetimeZone(s, x) then
    begin
      zone := x;
      continue;
    end;
    x := StrToIntDef(s, 0);
    // day or year
    if x > 0 then
      if (x < 32) and (day = 0) then
      begin
        day := x;
        continue;
      end
      else
      begin
        year := x;
        if year < 32 then
          year := year + 2000;
        if year < 1000 then
         year := year + 1900;
        continue;
      end;
    // time
    if rpos(':', s) > Pos(':', s) then
    begin
      t := GetTimeFromStr(s);
      if t <> 0 then
        Result := t;
      continue;
    end;
    //timezone daylight saving time
    if s = 'DST' then
    begin
      zone := zone + 60;
      continue;
    end;
    // month
    month := GetMonthNumber(s);
  end;
  Result := Result + Encodedate(year, month, day);
  zone := zone - TimeZoneBias;
  t := EncodeTime(Abs(zone) div 60, Abs(zone) mod 60, 0, 0);
  if zone < 0 then
    t := 0 - t;
  Result := Result - t;
end;

{==============================================================================}

function GetUTTime: TDateTime;
{$IFNDEF LINUX}
var
  st: TSystemTime;
begin
 GetSystemTime(st);
 result:=SystemTimeToDateTime(st);
{$ELSE}
var
  TV: TTimeVal;
begin
  gettimeofday(TV, nil);
  Result:=UnixDateDelta + (TV.tv_sec + TV.tv_usec / 1000000) / 86400;
{$ENDIF}
end;

{==============================================================================}

function SetUTTime(Newdt: TDateTime): Boolean;
{$IFNDEF LINUX}
var
  st: TSystemTime;
begin
 DateTimeToSystemTime(newdt,st);
 Result:=SetSystemTime(st);
{$ELSE}
var
  TV: TTimeVal;
  d: double;
  TZ: Ttimezone;
begin
  Result := false;
  gettimeofday(TV, TZ);
  d := (newdt - UnixDateDelta) * 86400;
  TV.tv_sec := trunc(d);
  TV.tv_usec := trunc(frac(d) * 1000000);
  Result := settimeofday(TV, TZ) <> -1;
{$ENDIF}
end;

{==============================================================================}

{$IFDEF LINUX}
function GetTick: Cardinal;
var
  Stamp: TTimeStamp;
begin
  Stamp := DateTimeToTimeStamp(Now);
  Result := Stamp.Time;
end;
{$ELSE}
function GetTick: Cardinal;
begin
  Result := Windows.GetTickCount;
end;
{$ENDIF}

{==============================================================================}

function CodeInt(Value: Word): string;
begin
  Result := Chr(Hi(Value)) + Chr(Lo(Value))
end;

{==============================================================================}

function DecodeInt(const Value: string; Index: Integer): Word;
var
  x, y: Byte;
begin
  if Length(Value) > Index then
    x := Ord(Value[Index])
  else
    x := 0;
  if Length(Value) >= (Index + 1) then
    y := Ord(Value[Index + 1])
  else
    y := 0;
  Result := x * 256 + y;
end;

{==============================================================================}

function IsIP(const Value: string): Boolean;
var
  n, x, i: Integer;
begin
  Result := true;
  if Pos('..',Value) > 0 then
    Result := False
  else
  begin
    i := 0;
    x := 0;
    for n := 1 to Length(Value) do
    begin
      if (Value[n] in ['0'..'9']) then
        i := i +1
      else
        if (Value[n] in ['.']) then
          i := 0
        else
          Result := False;
      if Value[n] = '.'
        then Inc(x);
      if i > 3 then
        result := False;
      if result = false then
        Break;
    end;
    if x <> 3 then
      Result := False;
  end;
end;

{==============================================================================}

function ReverseIP(Value: string): string;
var
  x: Integer;
begin
  Result := '';
  repeat
    x := LastDelimiter('.', Value);
    Result := Result + '.' + Copy(Value, x + 1, Length(Value) - x);
    Delete(Value, x, Length(Value) - x + 1);
  until x < 1;
  if Length(Result) > 0 then
    if Result[1] = '.' then
      Delete(Result, 1, 1);
end;

{==============================================================================}
//Hernan Sanchez
function IPToID(Host: string): string;
var
  s, t: string;
  i, x: Integer;
begin
  Result := '';
  for x := 1 to 3 do
  begin
    t := '';
    s := StrScan(PChar(Host), '.');
    t := Copy(Host, 1, (Length(Host) - Length(s)));
    Delete(Host, 1, (Length(Host) - Length(s) + 1));
    i := StrToIntDef(t, 0);
    Result := Result + Chr(i);
  end;
  i := StrToIntDef(Host, 0);
  Result := Result + Chr(i);
end;

{==============================================================================}

procedure Dump(const Buffer, DumpFile: string);
var
  n: Integer;
  s: string;
  f: Text;
begin
  s := '';
  for n := 1 to Length(Buffer) do
    s := s + ' +#$' + IntToHex(Ord(Buffer[n]), 2);
  AssignFile(f, DumpFile);
  if FileExists(DumpFile) then
    DeleteFile(PChar(DumpFile));
  Rewrite(f);
  try
    Writeln(f, s);
  finally
    CloseFile(f);
  end;
end;

{==============================================================================}

procedure DumpEx(const Buffer, DumpFile: string);
var
  n: Integer;
  x: Byte;
  s: string;
  f: Text;
begin
  s := '';
  for n := 1 to Length(Buffer) do
  begin
    x := Ord(Buffer[n]);
    if x in [65..90, 97..122] then
      s := s + ' +''' + char(x) + ''''
    else
      s := s + ' +#$' + IntToHex(Ord(Buffer[n]), 2);
  end;
  AssignFile(f, DumpFile);
  if FileExists(DumpFile) then
    DeleteFile(PChar(DumpFile));
  Rewrite(f);
  try
    Writeln(f, s);
  finally
    CloseFile(f);
  end;
end;

{==============================================================================}

function SeparateLeft(const Value, Delimiter: string): string;
var
  x: Integer;
begin
  x := Pos(Delimiter, Value);
  if x < 1 then
    Result := Trim(Value)
  else
    Result := Trim(Copy(Value, 1, x - 1));
end;

{==============================================================================}

function SeparateRight(const Value, Delimiter: string): string;
var
  x: Integer;
begin
  x := Pos(Delimiter, Value);
  if x > 0 then
    x := x + Length(Delimiter) - 1;
  Result := Trim(Copy(Value, x + 1, Length(Value) - x));
end;

{==============================================================================}

function GetParameter(const Value, Parameter: string): string;
var
  x, x1: Integer;
  s: string;
begin
  x := Pos(UpperCase(Parameter), UpperCase(Value));
  Result := '';
  if x > 0 then
  begin
    s := Copy(Value, x + Length(Parameter), Length(Value)
      - (x + Length(Parameter)) + 1);
    s := Trim(s);
    x1 := Length(s);
    if Length(s) > 1 then
    begin
      if s[1] = '"' then
      begin
        s := Copy(s, 2, Length(s) - 1);
        x := Pos('"', s);
        if x > 0 then
          x1 := x - 1;
      end
      else
      begin
        x := Pos(' ', s);
        if x > 0 then
          x1 := x - 1;
      end;
    end;
    Result := Copy(s, 1, x1);
  end;
end;

{==============================================================================}

function GetEmailAddr(const Value: string): string;
var
  s: string;
begin
  s := SeparateRight(Value, '<');
  s := SeparateLeft(s, '>');
  Result := Trim(s);
end;

{==============================================================================}

function GetEmailDesc(Value: string): string;
var
  s: string;
begin
  Value := Trim(Value);
  s := SeparateRight(Value, '"');
  if s <> Value then
    s := SeparateLeft(s, '"')
  else
  begin
    s := SeparateLeft(Value, '<');
    if s = Value then
    begin
      s := SeparateRight(Value, '(');
      if s <> Value then
        s := SeparateLeft(s, ')')
      else
        s := '';
    end;
  end;
  Result := Trim(s);
end;

{==============================================================================}

function StrToHex(const Value: string): string;
var
  n: Integer;
begin
  Result := '';
  for n := 1 to Length(Value) do
    Result := Result + IntToHex(Byte(Value[n]), 2);
  Result := LowerCase(Result);
end;

{==============================================================================}

function IntToBin(Value: Integer; Digits: Byte): string;
var
  x, y, n: Integer;
begin
  Result := '';
  x := Value;
  repeat
    y := x mod 2;
    x := x div 2;
    if y > 0 then
      Result := '1' + Result
    else
      Result := '0' + Result;
  until x = 0;
  x := Length(Result);
  for n := x to Digits - 1 do
    Result := '0' + Result;
end;

{==============================================================================}

function BinToInt(const Value: string): Integer;
var
  n: Integer;
begin
  Result := 0;
  for n := 1 to Length(Value) do
  begin
    if Value[n] = '0' then
      Result := Result * 2
    else
      if Value[n] = '1' then
        Result := Result * 2 + 1
      else
        Break;
  end;
end;

{==============================================================================}

function ParseURL(URL: string; var Prot, User, Pass, Host, Port, Path,
  Para: string): string;
var
  x: Integer;
  sURL: string;
  s: string;
  s1, s2: string;
begin
  Prot := 'http';
  User := '';
  Pass := '';
  Port := '80';
  Para := '';

  x := Pos('://', URL);
  if x > 0 then
  begin
    Prot := SeparateLeft(URL, '://');
    sURL := SeparateRight(URL, '://');
  end
  else
    sURL := URL;
  if UpperCase(Prot) = 'HTTPS' then
    Port := '443';
  if UpperCase(Prot) = 'FTP' then
    Port := '21';
  x := Pos('@', sURL);
  if (x > 0) and (x < Pos('/', sURL)) then
  begin
    s := SeparateLeft(sURL, '@');
    sURL := SeparateRight(sURL, '@');
    x := Pos(':', s);
    if x > 0 then
    begin
      User := SeparateLeft(s, ':');
      Pass := SeparateRight(s, ':');
    end
    else
      User := s;
  end;
  x := Pos('/', sURL);
  if x > 0 then
  begin
    s1 := SeparateLeft(sURL, '/');
    s2 := SeparateRight(sURL, '/');
  end
  else
  begin
    s1 := sURL;
    s2 := '';
  end;
  x := Pos(':', s1);
  if x > 0 then
  begin
    Host := SeparateLeft(s1, ':');
    Port := SeparateRight(s1, ':');
  end
  else
    Host := s1;
  Result := '/' + s2;
  x := Pos('?', s2);
  if x > 0 then
  begin
    Path := '/' + SeparateLeft(s2, '?');
    Para := SeparateRight(s2, '?');
  end
  else
    Path := '/' + s2;
  if Host = '' then
    Host := 'localhost';
end;

{==============================================================================}

function StringReplace(Value, Search, Replace: string): string;
var
  x, l, ls, lr: Integer;
begin
  if (Value = '') or (Search = '') then
  begin
    Result := Value;
    Exit;
  end;
  ls := Length(Search);
  lr := Length(Replace);
  Result := '';
  x := Pos(Search, Value);
  while x > 0 do
  begin
    l := Length(Result);
    SetLength(Result, l + x - 1);
    Move(Pointer(Value)^, Pointer(@Result[l + 1])^, x - 1);
//      Result:=Result+Copy(Value,1,x-1);
    l := Length(Result);
    SetLength(Result, l + lr);
    Move(Pointer(Replace)^, Pointer(@Result[l + 1])^, lr);
//      Result:=Result+Replace;
    Delete(Value, 1, x - 1 + ls);
    x := Pos(Search, Value);
  end;
  Result := Result + Value;
end;

{==============================================================================}

function RPosEx(const Sub, Value: string; From: integer): Integer;
var
  n: Integer;
  l: Integer;
begin
  result := 0;
  l := Length(Sub);
  for n := From - l + 1 downto 1 do
  begin
    if Copy(Value, n, l) = Sub then
    begin
      result := n;
      break;
    end;
  end;
end;

{==============================================================================}

function RPos(const Sub, Value: String): Integer;
begin
  Result := RPosEx(Sub, Value, Length(Value));
end;

{==============================================================================}

function Fetch(var Value: string; const Delimiter: string): string;
var
  s: string;
begin
  Result := SeparateLeft(Value, Delimiter);
  s := SeparateRight(Value, Delimiter);
  if s = Value then
    Value := ''
  else
    Value := Trim(s);
  Result := Trim(Result);
end;

end.
