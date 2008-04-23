{==============================================================================|
| Project : Delphree - Synapse                                   | 002.000.000 |
|==============================================================================|
| Content: SNMP client                                                         |
|==============================================================================|
| The contents of this file are subject to the Mozilla Public License Ver. 1.0 |
| (the "License"); you may not use this file except in compliance with the     |
| License. You may obtain a copy of the License at http://www.mozilla.org/MPL/ |
|                                                                              |
| Software distributed under the License is distributed on an "AS IS" basis,   |
| WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for |
| the specific language governing rights and limitations under the License.    |
|==============================================================================|
| The Original Code is Synapse Delphi Library.                                 |
|==============================================================================|
| The Initial Developer of the Original Code is Lukas Gebauer (Czech Republic).|
| Portions created by Lukas Gebauer are Copyright (c)2000.                     |
| All Rights Reserved.                                                         |
|==============================================================================|
| Contributor(s):                                                              |
|   Jean-Fabien Connault (jfconnault@mail.dotcom.fr)                           |
|==============================================================================|
| History: see HISTORY.HTM from distribution package                           |
|          (Found at URL: http://www.mlp.cz/space/gebauerl/synapse/)           |
|==============================================================================}

unit SNMPSend;

interface

uses
  BlckSock, synautil, classes, sysutils, ASN1util;

const

//PDU type
PDUGetRequest=$a0;
PDUGetNextRequest=$a1;
PDUGetResponse=$a2;
PDUSetRequest=$a3;
PDUTrap=$a4;

//errors
ENoError=0;
ETooBig=1;
ENoSuchName=2;
EBadValue=3;
EReadOnly=4;
EGenErr=5;

type

TSNMPMibValueType = (smvtInteger,
                     smvtOctetString,
                     smvtNull,
                     smvtObjectId,
                     smvtSequence,
                     smvtIpAddress,
                     smvtCounter,
                     smvtGauge,
                     smvtTimeTicks);

TSNMPMib = class
  OID: string;
  Value: string;
  ValueType: integer;
end;

TSNMPRec=class(TObject)
  public
    version:integer;
    community:string;
    PDUType:integer;
    ID:integer;
    ErrorStatus:integer;
    ErrorIndex:integer;
    SNMPMibList: TList;
    constructor Create;
    destructor Destroy; override;
    procedure DecodeBuf(Buffer:string);
    function EncodeBuf:string;
    procedure Clear;
    procedure MIBAdd(MIB,Value:string; ValueType:TSNMPMibValueType);
    procedure MIBdelete(Index:integer);
    function MIBGet(MIB:string):string;
    function ConvertValueType(ValueType: TSNMPMibValueType): integer;
end;

TSNMPSend=class(TObject)
  private
    Sock:TUDPBlockSocket;
    Buffer:string;
  public
    Timeout:integer;
    Host:string;
    Query:TSNMPrec;
    Reply:TSNMPrec;
    constructor Create;
    destructor Destroy; override;
    function DoIt:boolean;
end;

function SNMPget (Oid, Community, SNMPHost:string; var Value:string):Boolean;
function SNMPSet (Oid, Community, SNMPHost, Value: string; ValueType: TSNMPMibValueType): boolean;

implementation

{==============================================================================}

{TSNMPRec.Create}
constructor TSNMPRec.Create;
begin
  inherited create;
  SNMPMibList := TList.create;
end;

{TSNMPRec.Destroy}
destructor TSNMPRec.Destroy;
begin
  SNMPMibList.free;
  inherited destroy;
end;

{TSNMPRec.DecodeBuf}
procedure TSNMPRec.DecodeBuf(Buffer:string);
var
  Pos:integer;
  endpos:integer;
  sm,sv:string;
  svt: TSNMPMibValueType;
begin
  Pos:=2;
  Endpos:=ASNDecLen(Pos,buffer);
  Self.version:=StrToIntDef(ASNItem(Pos,buffer),0);
  Self.community:=ASNItem(Pos,buffer);
  Self.PDUType:=StrToIntDef(ASNItem(Pos,buffer),0);
  Self.ID:=StrToIntDef(ASNItem(Pos,buffer),0);
  Self.ErrorStatus:=StrToIntDef(ASNItem(Pos,buffer),0);
  Self.ErrorIndex:=StrToIntDef(ASNItem(Pos,buffer),0);
  ASNItem(Pos,buffer);
  while Pos<Endpos do
    begin
      ASNItem(Pos,buffer);
      Sm:=ASNItem(Pos,buffer);
      Sv:=ASNItem(Pos,buffer);
      Svt:=smvtNull;
      Self.MIBadd(sm,sv, svt);
    end;
end;

{TSNMPRec.EncodeBuf}
function TSNMPRec.EncodeBuf:string;
var
  data,s,t:string;
  SNMPMib: TSNMPMib;
  n:integer;
begin
  data:='';
  for n:=0 to SNMPMibList.Count-1 do
    begin
      SNMPMib := SNMPMibList[n];
      case (SNMPMib.ValueType) of
        ASN1_INT, ASN1_COUNTER, ASN1_GAUGE, ASN1_TIMETICKS:
          begin
            t := chr(strToInt('$'+copy(inttohex(strToInt(SNMPMib.Value),4),1,2)));
            t := t+chr(strToInt('$'+copy(inttohex(strToInt(SNMPMib.Value),4),3,2)));
            s := ASNObject(MibToID(SNMPMib.OID),6) + ASNObject(t,SNMPMib.ValueType);
          end;
      else
        s := ASNObject(MibToID(SNMPMib.OID),6) + ASNObject(SNMPMib.Value,SNMPMib.ValueType);
      end;
      data := data + ASNObject(s, $30);
    end;
  data:=ASNObject(data,$30);
  data:=ASNObject(char(Self.ID),2)
    +ASNObject(char(Self.ErrorStatus),2)
    +ASNObject(char(Self.ErrorIndex),2)
    +data;
  data:=ASNObject(char(Self.Version),2)
    +ASNObject(Self.community,4)
    +ASNObject(data,Self.PDUType);
  data:=ASNObject(data,$30);
  Result:=data;
end;

{TSNMPRec.Clear}
procedure TSNMPRec.Clear;
var
  i:integer;
begin
  version:=0;
  community:='';
  PDUType:=0;
  ID:=0;
  ErrorStatus:=0;
  ErrorIndex:=0;
  for i := 0 to SNMPMibList.count - 1 do
    TSNMPMib(SNMPMibList[i]).Free;
  SNMPMibList.Clear;
end;

{TSNMPRec.MIBAdd}
procedure TSNMPRec.MIBAdd(MIB,Value:string; ValueType:TSNMPMibValueType);
var
  SNMPMib: TSNMPMib;
begin
  SNMPMib := TSNMPMib.Create;
  SNMPMib.OID := MIB;
  SNMPMib.Value := Value;
  SNMPMib.ValueType := ConvertValueType(ValueType);
  SNMPMibList.Add(SNMPMib);
end;

{TSNMPRec.MIBdelete}
procedure TSNMPRec.MIBdelete(Index:integer);
begin
  if (Index >= 0) and (Index < SNMPMibList.count) then
    begin
      TSNMPMib(SNMPMibList[Index]).Free;
      SNMPMibList.Delete(Index);
    end;
end;

{TSNMPRec.MIBGet}
function TSNMPRec.MIBGet(MIB:string):string;
var
  i: integer;
begin
  Result := '';
  for i := 0 to SNMPMibList.count - 1 do
    begin
      if ((TSNMPMib(SNMPMibList[i])).OID = MIB) then
      begin
        Result := (TSNMPMib(SNMPMibList[i])).Value;
        break;
      end;
    end;
end;

{TSNMPRec.GetValueType}
function TSNMPRec.ConvertValueType(ValueType: TSNMPMibValueType): integer;
begin
  result := ASN1_NULL;
  if (ValueType = smvtInteger) then result := ASN1_INT;
  if (ValueType = smvtOctetString) then result := ASN1_OCTSTR;
  if (ValueType = smvtNull) then result := ASN1_NULL;
  if (ValueType = smvtObjectId) then result := ASN1_OBJID;
  if (ValueType = smvtSequence) then result := ASN1_SEQ;
  if (ValueType = smvtIpAddress) then result := ASN1_IPADDR;
  if (ValueType = smvtCounter) then result := ASN1_COUNTER;
  if (ValueType = smvtGauge) then result := ASN1_GAUGE;
  if (ValueType = smvtTimeTicks) then result := ASN1_TIMETICKS;
end;


{==============================================================================}

{TSNMPSend.Create}
constructor TSNMPSend.Create;
begin
  inherited create;
  Query:=TSNMPRec.Create;
  Reply:=TSNMPRec.Create;
  Query.Clear;
  Reply.Clear;
  sock:=TUDPBlockSocket.create;
  sock.createsocket;
  timeout:=5;
  host:='localhost';
end;

{TSNMPSend.Destroy}
destructor TSNMPSend.Destroy;
begin
  Sock.Free;
  Reply.Free;
  Query.Free;
  inherited destroy;
end;

{TSNMPSend.DoIt}
function TSNMPSend.DoIt:boolean;
var
  x:integer;
begin
  Result:=false;
  reply.clear;
  Buffer:=Query.Encodebuf;
  sock.connect(host,'161');
  sock.SendBuffer(PChar(Buffer),Length(Buffer));
  if sock.canread(timeout)
    then begin
      x:=sock.WaitingData;
      if x>0 then
        begin
          setlength(Buffer,x);
          sock.RecvBuffer(PChar(Buffer),x);
          result:=true;
        end;
    end;
  if Result
    then reply.DecodeBuf(Buffer);
end;

{==============================================================================}

function SNMPget (Oid, Community, SNMPHost:string; var Value:string):Boolean;
var
  SNMP:TSNMPSend;
begin
  Result:=False;
  SNMP:=TSNMPSend.Create;
  try
    Snmp.Query.community:=Community;
    Snmp.Query.PDUType:=PDUGetRequest;
    Snmp.Query.MIBAdd(Oid,'',smvtNull);
    Snmp.host:=SNMPHost;
    Result:=Snmp.DoIt;
    if Result then
      Value:=Snmp.Reply.MIBGet(Oid);
  finally
    SNMP.Free;
  end;
end;

function SNMPSet(Oid, Community, SNMPHost, Value: string; ValueType: TSNMPMibValueType): boolean;
var
  SNMPSend: TSNMPSend;
begin
  SNMPSend := TSNMPSend.Create;
  try
    SNMPSend.Query.community := Community;
    SNMPSend.Query.PDUType := PDUSetRequest;
    SNMPSend.Query.MIBAdd(Oid, Value, ValueType);
    SNMPSend.Host := SNMPHost;
    result:= SNMPSend.DoIt=true;
  finally
    SNMPSend.Free;
  end;
end;


end.
