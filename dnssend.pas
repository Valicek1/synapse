{==============================================================================|
| Project : Delphree - Synapse                                   | 002.001.001 |
|==============================================================================|
| Content: DNS client                                                          |
|==============================================================================|
| Copyright (c)1999-2003, Lukas Gebauer                                        |
| All rights reserved.                                                         |
|                                                                              |
| Redistribution and use in source and binary forms, with or without           |
| modification, are permitted provided that the following conditions are met:  |
|                                                                              |
| Redistributions of source code must retain the above copyright notice, this  |
| list of conditions and the following disclaimer.                             |
|                                                                              |
| Redistributions in binary form must reproduce the above copyright notice,    |
| this list of conditions and the following disclaimer in the documentation    |
| and/or other materials provided with the distribution.                       |
|                                                                              |
| Neither the name of Lukas Gebauer nor the names of its contributors may      |
| be used to endorse or promote products derived from this software without    |
| specific prior written permission.                                           |
|                                                                              |
| THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"  |
| AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE    |
| IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE   |
| ARE DISCLAIMED. IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE FOR  |
| ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL       |
| DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR   |
| SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER   |
| CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT           |
| LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY    |
| OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH  |
| DAMAGE.                                                                      |
|==============================================================================|
| The Initial Developer of the Original Code is Lukas Gebauer (Czech Republic).|
| Portions created by Lukas Gebauer are Copyright (c)2000-2003.                |
| All Rights Reserved.                                                         |
|==============================================================================|
| Contributor(s):                                                              |
|==============================================================================|
| History: see HISTORY.HTM from distribution package                           |
|          (Found at URL: http://www.ararat.cz/synapse/)                       |
|==============================================================================}

// RFC-1035, RFC-1183, RFC1706, RFC1712, RFC2163, RFC2230

{$Q-}
{$WEAKPACKAGEUNIT ON}

unit DNSsend;

interface

uses
  SysUtils, Classes,
  blcksock, SynaUtil;

const
  cDnsProtocol = 'domain';

  QTYPE_A = 1;
  QTYPE_NS = 2;
  QTYPE_MD = 3;
  QTYPE_MF = 4;
  QTYPE_CNAME = 5;
  QTYPE_SOA = 6;
  QTYPE_MB = 7;
  QTYPE_MG = 8;
  QTYPE_MR = 9;
  QTYPE_NULL = 10;
  QTYPE_WKS = 11; //
  QTYPE_PTR = 12;
  QTYPE_HINFO = 13;
  QTYPE_MINFO = 14;
  QTYPE_MX = 15;
  QTYPE_TXT = 16;

  QTYPE_RP = 17;
  QTYPE_AFSDB = 18;
  QTYPE_X25 = 19;
  QTYPE_ISDN = 20;
  QTYPE_RT = 21;
  QTYPE_NSAP = 22;
  QTYPE_NSAPPTR = 23;
  QTYPE_SIG = 24; // RFC-2065
  QTYPE_KEY = 25; // RFC-2065
  QTYPE_PX = 26;
  QTYPE_GPOS = 27;
  QTYPE_AAAA = 28; // IP6 Address  [Susan Thomson]
  QTYPE_LOC = 29; // RFC-1876
  QTYPE_NXT = 30; // RFC-2065

  QTYPE_SRV = 33; // RFC-2052
  QTYPE_NAPTR = 35; // RFC-2168
  QTYPE_KX = 36;

  QTYPE_AXFR = 252;
  QTYPE_MAILB = 253; //
  QTYPE_MAILA = 254; //
  QTYPE_ALL = 255;

type
  TDNSSend = class(TSynaClient)
  private
    FID: Word;
    FRCode: Integer;
    FBuffer: string;
    FSock: TUDPBlockSocket;
    FTCPSock: TTCPBlockSocket;
    FUseTCP: Boolean;
    FAnsferInfo: TStringList;
    FNameserverInfo: TStringList;
    FAdditionalInfo: TStringList;
    FAuthoritative: Boolean;
    function CompressName(const Value: string): string;
    function CodeHeader: string;
    function CodeQuery(const Name: string; QType: Integer): string;
    function DecodeLabels(var From: Integer): string;
    function DecodeString(var From: Integer): string;
    function DecodeResource(var i: Integer; const Info: TStringList;
      QType: Integer): string;
    function RecvTCPResponse(const WorkSock: TBlockSocket): string;
    function DecodeResponse(const Buf: string; const Reply: TStrings;
      QType: Integer):boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function DNSQuery(Name: string; QType: Integer;
      const Reply: TStrings): Boolean;
  published
    property Sock: TUDPBlockSocket read FSock;
    property TCPSock: TTCPBlockSocket read FTCPSock;
    property UseTCP: Boolean read FUseTCP Write FUseTCP;
    property RCode: Integer read FRCode;
    property Authoritative: Boolean read FAuthoritative;
    property AnsferInfo: TStringList read FAnsferInfo;
    property NameserverInfo: TStringList read FNameserverInfo;
    property AdditionalInfo: TStringList read FAdditionalInfo;
  end;

function GetMailServers(const DNSHost, Domain: string;
  const Servers: TStrings): Boolean;

implementation

constructor TDNSSend.Create;
begin
  inherited Create;
  FSock := TUDPBlockSocket.Create;
  FTCPSock := TTCPBlockSocket.Create;
  FUseTCP := False;
  FTimeout := 10000;
  FTargetPort := cDnsProtocol;
  FAnsferInfo := TStringList.Create;
  FNameserverInfo := TStringList.Create;
  FAdditionalInfo := TStringList.Create;
  Randomize;
end;

destructor TDNSSend.Destroy;
begin
  FAnsferInfo.Free;
  FNameserverInfo.Free;
  FAdditionalInfo.Free;
  FTCPSock.Free;
  FSock.Free;
  inherited Destroy;
end;

function TDNSSend.CompressName(const Value: string): string;
var
  n: Integer;
  s: string;
begin
  Result := '';
  if Value = '' then
    Result := #0
  else
  begin
    s := '';
    for n := 1 to Length(Value) do
      if Value[n] = '.' then
      begin
        Result := Result + Char(Length(s)) + s;
        s := '';
      end
      else
        s := s + Value[n];
    if s <> '' then
      Result := Result + Char(Length(s)) + s;
    Result := Result + #0;
  end;
end;

function TDNSSend.CodeHeader: string;
begin
  FID := Random(32767);
  Result := CodeInt(FID); // ID
  Result := Result + CodeInt($0100); // flags
  Result := Result + CodeInt(1); // QDCount
  Result := Result + CodeInt(0); // ANCount
  Result := Result + CodeInt(0); // NSCount
  Result := Result + CodeInt(0); // ARCount
end;

function TDNSSend.CodeQuery(const Name: string; QType: Integer): string;
begin
  Result := CompressName(Name);
  Result := Result + CodeInt(QType);
  Result := Result + CodeInt(1); // Type INTERNET
end;

function TDNSSend.DecodeString(var From: Integer): string;
var
  Len: integer;
begin
  Len := Ord(FBuffer[From]);
  Inc(From);
  Result := Copy(FBuffer, From, Len);
  Inc(From, Len);
end;

function TDNSSend.DecodeLabels(var From: Integer): string;
var
  l, f: Integer;
begin
  Result := '';
  while True do
  begin
    if From >= Length(FBuffer) then
      Break;
    l := Ord(FBuffer[From]);
    Inc(From);
    if l = 0 then
      Break;
    if Result <> '' then
      Result := Result + '.';
    if (l and $C0) = $C0 then
    begin
      f := l and $3F;
      f := f * 256 + Ord(FBuffer[From]) + 1;
      Inc(From);
      Result := Result + DecodeLabels(f);
      Break;
    end
    else
    begin
      Result := Result + Copy(FBuffer, From, l);
      Inc(From, l);
    end;
  end;
end;

function TDNSSend.DecodeResource(var i: Integer; const Info: TStringList;
  QType: Integer): string;
var
  Rname: string;
  RType, Len, j, x, n: Integer;
  R: string;
  t1, t2, ttl: integer;
begin
  Result := '';
  R := '';
  Rname := DecodeLabels(i);
  RType := DecodeInt(FBuffer, i);
  Inc(i, 4);
  t1 := DecodeInt(FBuffer, i);
  Inc(i, 2);
  t2 := DecodeInt(FBuffer, i);
  Inc(i, 2);
  ttl := t1 * 65536 + t2;
  Len := DecodeInt(FBuffer, i);
  Inc(i, 2); // i point to begin of data
  j := i;
  i := i + len; // i point to next record
  case RType of
    QTYPE_A:
      begin
        R := IntToStr(Ord(FBuffer[j]));
        Inc(j);
        R := R + '.' + IntToStr(Ord(FBuffer[j]));
        Inc(j);
        R := R + '.' + IntToStr(Ord(FBuffer[j]));
        Inc(j);
        R := R + '.' + IntToStr(Ord(FBuffer[j]));
      end;
    QTYPE_NS, QTYPE_MD, QTYPE_MF, QTYPE_CNAME, QTYPE_MB,
      QTYPE_MG, QTYPE_MR, QTYPE_PTR, QTYPE_X25, QTYPE_NSAP,
      QTYPE_NSAPPTR:
      R := DecodeLabels(j);
    QTYPE_SOA:
      begin
        R := DecodeLabels(j);
        R := R + ',' + DecodeLabels(j);
        for n := 1 to 5 do
        begin
          x := DecodeInt(FBuffer, j) * 65536 + DecodeInt(FBuffer, j + 2);
          Inc(j, 4);
          R := R + ',' + IntToStr(x);
        end;
      end;
    QTYPE_NULL:
      begin
      end;
    QTYPE_WKS:
      begin
      end;
    QTYPE_HINFO:
      begin
        R := DecodeString(j);
        R := R + ',' + DecodeString(j);
      end;
    QTYPE_MINFO, QTYPE_RP, QTYPE_ISDN:
      begin
        R := DecodeLabels(j);
        R := R + ',' + DecodeLabels(j);
      end;
    QTYPE_MX, QTYPE_AFSDB, QTYPE_RT, QTYPE_KX:
      begin
        x := DecodeInt(FBuffer, j);
        Inc(j, 2);
        R := IntToStr(x);
        R := R + ',' + DecodeLabels(j);
      end;
    QTYPE_TXT:
      R := DecodeString(j);
    QTYPE_GPOS:
      begin
        R := DecodeLabels(j);
        R := R + ',' + DecodeLabels(j);
        R := R + ',' + DecodeLabels(j);
      end;
    QTYPE_PX:
      begin
        x := DecodeInt(FBuffer, j);
        Inc(j, 2);
        R := IntToStr(x);
        R := R + ',' + DecodeLabels(j);
        R := R + ',' + DecodeLabels(j);
      end;
  end;
  if R <> '' then
    Info.Add(RName + ',' + IntToStr(RType) + ',' + IntToStr(ttl) + ',' + R);
  if QType = RType then
    Result := R;
end;

function TDNSSend.RecvTCPResponse(const WorkSock: TBlockSocket): string;
var
  l: integer;
begin
  Result := '';
  l := WorkSock.recvbyte(FTimeout) * 256 + WorkSock.recvbyte(FTimeout);
  if l > 0 then
    Result := WorkSock.RecvBufferStr(l, FTimeout);
end;

function TDNSSend.DecodeResponse(const Buf: string; const Reply: TStrings;
  QType: Integer):boolean;
var
  n, i: Integer;
  flag, qdcount, ancount, nscount, arcount: Integer;
  s: string;
begin
  Result := False;
  Reply.Clear;
  FAnsferInfo.Clear;
  FNameserverInfo.Clear;
  FAdditionalInfo.Clear;
  FAuthoritative := False;
  if (Length(Buf) > 13) and (FID = DecodeInt(Buf, 1)) then
  begin
    flag := DecodeInt(Buf, 3);
    FRCode := Flag and $000F;
    FAuthoritative := (Flag and $0400) > 0;
    if FRCode = 0 then
    begin
      qdcount := DecodeInt(Buf, 5);
      ancount := DecodeInt(Buf, 7);
      nscount := DecodeInt(Buf, 9);
      arcount := DecodeInt(Buf, 11);
      i := 13; //begin of body
      if (qdcount > 0) and (Length(Buf) > i) then //skip questions
        for n := 1 to qdcount do
        begin
          while (Buf[i] <> #0) and ((Ord(Buf[i]) and $C0) <> $C0) do
            Inc(i);
          Inc(i, 5);
        end;
      if (ancount > 0) and (Length(Buf) > i) then // decode reply
        for n := 1 to ancount do
        begin
          s := DecodeResource(i, FAnsferInfo, QType);
          if s <> '' then
            Reply.Add(s);
        end;
      if (nscount > 0) and (Length(Buf) > i) then // decode nameserver info
        for n := 1 to nscount do
          DecodeResource(i, FNameserverInfo, QType);
      if (arcount > 0) and (Length(Buf) > i) then // decode additional info
        for n := 1 to arcount do
          DecodeResource(i, FAdditionalInfo, QType);
      Result := True;
    end;
  end;
end;

function TDNSSend.DNSQuery(Name: string; QType: Integer;
  const Reply: TStrings): Boolean;
var
  WorkSock: TBlockSocket;
  t: TStringList;
  b: boolean;
begin
  Result := False;
  if IsIP(Name) then
    Name := ReverseIP(Name) + '.in-addr.arpa';
  FBuffer := CodeHeader + CodeQuery(Name, QType);
  if FUseTCP then
    WorkSock := FTCPSock
  else
    WorkSock := FSock;
  WorkSock.Bind(FIPInterface, cAnyPort);
  WorkSock.Connect(FTargetHost, FTargetPort);
  if FUseTCP then
    FBuffer := Codeint(length(FBuffer)) + FBuffer;
  WorkSock.SendString(FBuffer);
  if FUseTCP then
    FBuffer := RecvTCPResponse(WorkSock)
  else
    FBuffer := WorkSock.RecvPacket(FTimeout);
  if FUseTCP and (QType = QTYPE_AXFR) then //zone transfer
  begin
    t := TStringList.Create;
    try
      repeat
        b := DecodeResponse(FBuffer, Reply, QType);
        if (t.Count > 1) and (AnsferInfo.Count > 0) then  //find end of transfer
          b := b and (t[0] <> AnsferInfo[AnsferInfo.count - 1]);
        if b then
        begin
          t.AddStrings(AnsferInfo);
          FBuffer := RecvTCPResponse(WorkSock);
          if FBuffer = '' then
            Break;
          if WorkSock.LastError <> 0 then
            Break;
        end;
      until not b;
      Reply.Assign(t);
      Result := True;
    finally
      t.free;
    end;
  end
  else //normal query
    if WorkSock.LastError = 0 then
      Result := DecodeResponse(FBuffer, Reply, QType);
end;

{==============================================================================}

function GetMailServers(const DNSHost, Domain: string;
  const Servers: TStrings): Boolean;
var
  DNS: TDNSSend;
  t: TStringList;
  n, m, x: Integer;
begin
  Result := False;
  Servers.Clear;
  t := TStringList.Create;
  DNS := TDNSSend.Create;
  try
    DNS.TargetHost := DNSHost;
    if DNS.DNSQuery(Domain, QType_MX, t) then
    begin
      { normalize preference number to 5 digits }
      for n := 0 to t.Count - 1 do
      begin
        x := Pos(',', t[n]);
        if x > 0 then
          for m := 1 to 6 - x do
            t[n] := '0' + t[n];
      end;
      { sort server list }
      t.Sorted := True;
      { result is sorted list without preference numbers }
      for n := 0 to t.Count - 1 do
      begin
        x := Pos(',', t[n]);
        Servers.Add(Copy(t[n], x + 1, Length(t[n]) - x));
      end;
      Result := True;
    end;
  finally
    DNS.Free;
    t.Free;
  end;
end;

end.
