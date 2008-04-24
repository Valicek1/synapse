{==============================================================================|
| Project : Ararat Synapse                                       | 002.007.000 |
|==============================================================================|
| Content: FTP client                                                          |
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
| Portions created by Lukas Gebauer are Copyright (c) 1999-2003.               |
| All Rights Reserved.                                                         |
|==============================================================================|
| Contributor(s):                                                              |
|   Petr Esner <petr.esner@atlas.cz>                                           |
|==============================================================================|
| History: see HISTORY.HTM from distribution package                           |
|          (Found at URL: http://www.ararat.cz/synapse/)                       |
|==============================================================================}

// RFC-959, RFC-2228, RFC-2428

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}
{$H+}

unit ftpsend;

interface

uses
  SysUtils, Classes,
  {$IFDEF STREAMSEC}
  TlsInternalServer, TlsSynaSock,
  {$ENDIF}
  blcksock, synautil, synacode;

const
  cFtpProtocol = 'ftp';
  cFtpDataProtocol = 'ftp-data';

  FTP_OK = 255;
  FTP_ERR = 254;

type
  TLogonActions = array [0..17] of byte;

  TFTPStatus = procedure(Sender: TObject; Response: Boolean;
    const Value: string) of object;

  TFTPListRec = class(TObject)
  public
    FileName: string;
    Directory: Boolean;
    Readable: Boolean;
    FileSize: Longint;
    FileTime: TDateTime;
  end;

  TFTPList = class(TObject)
  private
    FList: TList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function ParseLine(Value: string): Boolean;
  published
    property List: TList read FList;
  end;

  TFTPSend = class(TSynaClient)
  private
    FOnStatus: TFTPStatus;
    {$IFDEF STREAMSEC}
    FSock: TSsTCPBlockSocket;
    FDSock: TSsTCPBlockSocket;
    FTLSServer: TCustomTLSInternalServer;
    {$ELSE}
    FSock: TTCPBlockSocket;
    FDSock: TTCPBlockSocket;
    {$ENDIF}
    FResultCode: Integer;
    FResultString: string;
    FFullResult: TStringList;
    FUsername: string;
    FPassword: string;
    FAccount: string;
    FFWHost: string;
    FFWPort: string;
    FFWUsername: string;
    FFWPassword: string;
    FFWMode: integer;
    FDataStream: TMemoryStream;
    FDataIP: string;
    FDataPort: string;
    FDirectFile: Boolean;
    FDirectFileName: string;
    FCanResume: Boolean;
    FPassiveMode: Boolean;
    FForceDefaultPort: Boolean;
    FFtpList: TFTPList;
    FBinaryMode: Boolean;
    FAutoTLS: Boolean;
    FIsTLS: Boolean;
    FIsDataTLS: Boolean;
    FTLSonData: Boolean;
    FFullSSL: Boolean;
    function Auth(Mode: integer): Boolean;
    function Connect: Boolean;
    function InternalStor(const Command: string; RestoreAt: integer): Boolean;
    function DataSocket: Boolean;
    function AcceptDataSocket: Boolean;
  protected
    procedure DoStatus(Response: Boolean; const Value: string);
  public
    CustomLogon: TLogonActions;
    constructor Create;
    destructor Destroy; override;
    function ReadResult: Integer;
    procedure ParseRemote(Value: string);
    procedure ParseRemoteEPSV(Value: string);
    function FTPCommand(const Value: string): integer;
    function Login: Boolean;
    procedure Logout;
    procedure Abort;
    function List(Directory: string; NameList: Boolean): Boolean;
    function RetrieveFile(const FileName: string; Restore: Boolean): Boolean;
    function StoreFile(const FileName: string; Restore: Boolean): Boolean;
    function StoreUniqueFile: Boolean;
    function AppendFile(const FileName: string): Boolean;
    function RenameFile(const OldName, NewName: string): Boolean;
    function DeleteFile(const FileName: string): Boolean;
    function FileSize(const FileName: string): integer;
    function NoOp: Boolean;
    function ChangeWorkingDir(const Directory: string): Boolean;
    function ChangeToRootDir: Boolean;
    function DeleteDir(const Directory: string): Boolean;
    function CreateDir(const Directory: string): Boolean;
    function GetCurrentDir: String;
    function DataRead(const DestStream: TStream): Boolean;
    function DataWrite(const SourceStream: TStream): Boolean;
  published
    property ResultCode: Integer read FResultCode;
    property ResultString: string read FResultString;
    property FullResult: TStringList read FFullResult;
    property Username: string read FUsername Write FUsername;
    property Password: string read FPassword Write FPassword;
    property Account: string read FAccount Write FAccount;
    property FWHost: string read FFWHost Write FFWHost;
    property FWPort: string read FFWPort Write FFWPort;
    property FWUsername: string read FFWUsername Write FFWUsername;
    property FWPassword: string read FFWPassword Write FFWPassword;
    property FWMode: integer read FFWMode Write FFWMode;
{$IFDEF STREAMSEC}
    property Sock: TSsTCPBlockSocket read FSock;
    property DSock: TSsTCPBlockSocket read FDSock;
    property TLSServer: TCustomTLSInternalServer read FTLSServer write FTLSServer;
{$ELSE}
    property Sock: TTCPBlockSocket read FSock;
    property DSock: TTCPBlockSocket read FDSock;
{$ENDIF}
    property DataStream: TMemoryStream read FDataStream;
    property DataIP: string read FDataIP;
    property DataPort: string read FDataPort;
    property DirectFile: Boolean read FDirectFile Write FDirectFile;
    property DirectFileName: string read FDirectFileName Write FDirectFileName;
    property CanResume: Boolean read FCanResume;
    property PassiveMode: Boolean read FPassiveMode Write FPassiveMode;
    property ForceDefaultPort: Boolean read FForceDefaultPort Write FForceDefaultPort;
    property OnStatus: TFTPStatus read FOnStatus write FOnStatus;
    property FtpList: TFTPList read FFtpList;
    property BinaryMode: Boolean read FBinaryMode Write FBinaryMode;
    property AutoTLS: Boolean read FAutoTLS Write FAutoTLS;
    property FullSSL: Boolean read FFullSSL Write FFullSSL;
    property IsTLS: Boolean read FIsTLS;
    property IsDataTLS: Boolean read FIsDataTLS;
    property TLSonData: Boolean read FTLSonData write FTLSonData;
  end;

function FtpGetFile(const IP, Port, FileName, LocalFile,
  User, Pass: string): Boolean;
function FtpPutFile(const IP, Port, FileName, LocalFile,
  User, Pass: string): Boolean;
function FtpInterServerTransfer(
  const FromIP, FromPort, FromFile, FromUser, FromPass: string;
  const ToIP, ToPort, ToFile, ToUser, ToPass: string): Boolean;

implementation

constructor TFTPSend.Create;
begin
  inherited Create;
  FFullResult := TStringList.Create;
  FDataStream := TMemoryStream.Create;
{$IFDEF STREAMSEC}
  FTLSServer := GlobalTLSInternalServer;
  FSock := TSsTCPBlockSocket.Create;
  FSock.BlockingRead := True;
  FSock.ConvertLineEnd := True;
  FDSock := TSsTCPBlockSocket.Create;
  FDSock.BlockingRead := True;
{$ELSE}
  FSock := TTCPBlockSocket.Create;
  FSock.ConvertLineEnd := True;
  FDSock := TTCPBlockSocket.Create;
{$ENDIF}
  FFtpList := TFTPList.Create;
  FTimeout := 300000;
  FTargetPort := cFtpProtocol;
  FUsername := 'anonymous';
  FPassword := 'anonymous@' + FSock.LocalName;
  FDirectFile := False;
  FPassiveMode := True;
  FForceDefaultPort := False;
  FAccount := '';
  FFWHost := '';
  FFWPort := cFtpProtocol;
  FFWUsername := '';
  FFWPassword := '';
  FFWMode := 0;
  FBinaryMode := True;
  FAutoTLS := False;
  FFullSSL := False;
  FIsTLS := False;
  FIsDataTLS := False;
  FTLSonData := True;
end;

destructor TFTPSend.Destroy;
begin
  FDSock.Free;
  FSock.Free;
  FFTPList.Free;
  FDataStream.Free;
  FFullResult.Free;
  inherited Destroy;
end;

procedure TFTPSend.DoStatus(Response: Boolean; const Value: string);
begin
  if assigned(OnStatus) then
    OnStatus(Self, Response, Value);
end;

function TFTPSend.ReadResult: Integer;
var
  s,c: string;
begin
  Result := 0;
  FFullResult.Clear;
  c := '';
  repeat
    s := FSock.RecvString(FTimeout);
    if c = '' then
      c :=Copy(s, 1, 3)+' ';
    FResultString := s;
    FFullResult.Add(s);
    if FSock.LastError <> 0 then
      Break;
  until Pos(c, s) = 1;
  s := FFullResult[0];
  if Length(s) >= 3 then
    Result := StrToIntDef(Copy(s, 1, 3), 0);
  FResultCode := Result;
end;

function TFTPSend.FTPCommand(const Value: string): integer;
begin
  FSock.SendString(Value + CRLF);
  DoStatus(False, Value);
  Result := ReadResult;
  DoStatus(True, FResultString);
end;

// based on idea by Petr Esner <petr.esner@atlas.cz>
function TFTPSend.Auth(Mode: integer): Boolean;
const
  //if not USER <username> then
  //  if not PASS <password> then
  //    if not ACCT <account> then ERROR!
  //OK!
  Action0: TLogonActions =
    (0, FTP_OK, 3,
     1, FTP_OK, 6,
     2, FTP_OK, FTP_ERR,
     0, 0, 0, 0, 0, 0, 0, 0, 0);

  //if not USER <FWusername> then
  //  if not PASS <FWPassword> then ERROR!
  //if SITE <FTPServer> then ERROR!
  //if not USER <username> then
  //  if not PASS <password> then
  //    if not ACCT <account> then ERROR!
  //OK!
  Action1: TLogonActions =
    (3, 6, 3,
     4, 6, FTP_ERR,
     5, FTP_ERR, 9,
     0, FTP_OK, 12,
     1, FTP_OK, 15,
     2, FTP_OK, FTP_ERR);

  //if not USER <FWusername> then
  //  if not PASS <FWPassword> then ERROR!
  //if USER <UserName>'@'<FTPServer> then OK!
  //if not PASS <password> then
  //  if not ACCT <account> then ERROR!
  //OK!
  Action2: TLogonActions =
    (3, 6, 3,
     4, 6, FTP_ERR,
     6, FTP_OK, 9,
     1, FTP_OK, 12,
     2, FTP_OK, FTP_ERR,
     0, 0, 0);

  //if not USER <FWusername> then
  //  if not PASS <FWPassword> then ERROR!
  //if not USER <username> then
  //  if not PASS <password> then
  //    if not ACCT <account> then ERROR!
  //OK!
  Action3: TLogonActions =
    (3, 6, 3,
     4, 6, FTP_ERR,
     0, FTP_OK, 9,
     1, FTP_OK, 12,
     2, FTP_OK, FTP_ERR,
     0, 0, 0);

  //OPEN <FTPserver>
  //if not USER <username> then
  //  if not PASS <password> then
  //    if not ACCT <account> then ERROR!
  //OK!
  Action4: TLogonActions =
    (7, 3, 3,
     0, FTP_OK, 6,
     1, FTP_OK, 9,
     2, FTP_OK, FTP_ERR,
     0, 0, 0, 0, 0, 0);

  //if USER <UserName>'@'<FTPServer> then OK!
  //if not PASS <password> then
  //  if not ACCT <account> then ERROR!
  //OK!
  Action5: TLogonActions =
    (6, FTP_OK, 3,
     1, FTP_OK, 6,
     2, FTP_OK, FTP_ERR,
     0, 0, 0, 0, 0, 0, 0, 0, 0);

  //if not USER <FWUserName>@<FTPServer> then
  //  if not PASS <FWPassword> then ERROR!
  //if not USER <username> then
  //  if not PASS <password> then
  //    if not ACCT <account> then ERROR!
  //OK!
  Action6: TLogonActions =
    (8, 6, 3,
     4, 6, FTP_ERR,
     0, FTP_OK, 9,
     1, FTP_OK, 12,
     2, FTP_OK, FTP_ERR,
     0, 0, 0);

  //if USER <UserName>@<FTPServer> <FWUserName> then ERROR!
  //if not PASS <password> then
  //  if not ACCT <account> then ERROR!
  //OK!
  Action7: TLogonActions =
    (9, FTP_ERR, 3,
     1, FTP_OK, 6,
     2, FTP_OK, FTP_ERR,
     0, 0, 0, 0, 0, 0, 0, 0, 0);

  //if not USER <UserName>@<FWUserName>@<FTPServer> then
  //  if not PASS <Password>@<FWPassword> then
  //    if not ACCT <account> then ERROR!
  //OK!
  Action8: TLogonActions =
    (10, FTP_OK, 3,
     11, FTP_OK, 6,
     2, FTP_OK, FTP_ERR,
     0, 0, 0, 0, 0, 0, 0, 0, 0);
var
  FTPServer: string;
  LogonActions: TLogonActions;
  i: integer;
  s: string;
  x: integer;
begin
  Result := False;
  if FFWHost = '' then
    Mode := 0;
  if (FTargetPort = cFtpProtocol) or (FTargetPort = '21') then
    FTPServer := FTargetHost
  else
    FTPServer := FTargetHost + ':' + FTargetPort;
  case Mode of
    -1:
      LogonActions := CustomLogon;
    1:
      LogonActions := Action1;
    2:
      LogonActions := Action2;
    3:
      LogonActions := Action3;
    4:
      LogonActions := Action4;
    5:
      LogonActions := Action5;
    6:
      LogonActions := Action6;
    7:
      LogonActions := Action7;
    8:
      LogonActions := Action8;
  else
    LogonActions := Action0;
  end;
  i := 0;
  repeat
    case LogonActions[i] of
      0:  s := 'USER ' + FUserName;
      1:  s := 'PASS ' + FPassword;
      2:  s := 'ACCT ' + FAccount;
      3:  s := 'USER ' + FFWUserName;
      4:  s := 'PASS ' + FFWPassword;
      5:  s := 'SITE ' + FTPServer;
      6:  s := 'USER ' + FUserName + '@' + FTPServer;
      7:  s := 'OPEN ' + FTPServer;
      8:  s := 'USER ' + FFWUserName + '@' + FTPServer;
      9:  s := 'USER ' + FUserName + '@' + FTPServer + ' ' + FFWUserName;
      10: s := 'USER ' + FUserName + '@' + FFWUserName + '@' + FTPServer;
      11: s := 'PASS ' + FPassword + '@' + FFWPassword;
    end;
    x := FTPCommand(s);
    x := x div 100;
    if (x <> 2) and (x <> 3) then
      Exit;
    i := LogonActions[i + x - 1];
    case i of
      FTP_ERR:
        Exit;
      FTP_OK:
        begin
          Result := True;
          Exit;
        end;
    end;
  until False;
end;


function TFTPSend.Connect: Boolean;
begin
  FSock.CloseSocket;
  FSock.Bind(FIPInterface, cAnyPort);
{$IFDEF STREAMSEC}
  if FFullSSL then
  begin
    if assigned(FTLSServer) then
      FSock.TLSServer := FTLSServer
    else
    begin
      result := False;
      Exit;
    end;
  end
  else
    FSock.TLSServer := nil;
{$ELSE}
  if FFullSSL then
    FSock.SSLEnabled := True;
{$ENDIF}
  if FSock.LastError = 0 then
    if FFWHost = '' then
      FSock.Connect(FTargetHost, FTargetPort)
    else
      FSock.Connect(FFWHost, FFWPort);
  Result := FSock.LastError = 0;
end;

function TFTPSend.Login: Boolean;
begin
  Result := False;
  FCanResume := False;
  if not Connect then
    Exit;
  FIsTLS := FFullSSL;
  FIsDataTLS := False;
  if (ReadResult div 100) <> 2 then
    Exit;
  if FAutoTLS and not(FIsTLS) then
    if (FTPCommand('AUTH TLS') div 100) = 2 then
    begin
{$IFDEF STREAMSEC}
      if Assigned(FTLSServer) then
      begin
        Fsock.TLSServer := FTLSServer;
        Fsock.Connect('','');
        FIsTLS := FSock.LastError = 0;
      end
      else
        Result := False;
{$ELSE}
      FSock.SSLDoConnect;
      FIsTLS := FSock.LastError = 0;
      FDSock.SSLCertificateFile := FSock.SSLCertificateFile;
      FDSock.SSLPrivateKeyFile := FSock.SSLPrivateKeyFile;
      FDSock.SSLCertCAFile := FSock.SSLCertCAFile;
{$ENDIF}
    end;
  if not Auth(FFWMode) then
    Exit;
  if FIsTLS then
  begin
    if FTLSonData then
      FIsDataTLS := (FTPCommand('PROT P') div 100) = 2;
    if not FIsDataTLS then
      FTPCommand('PROT C');
    FTPCommand('PBSZ 0');
  end;
  FTPCommand('TYPE I');
  FTPCommand('STRU F');
  FTPCommand('MODE S');
  if FTPCommand('REST 0') = 350 then
    if FTPCommand('REST 1') = 350 then
    begin
      FTPCommand('REST 0');
      FCanResume := True;
    end;
  Result := True;
end;

procedure TFTPSend.Logout;
begin
  FTPCommand('QUIT');
  FSock.CloseSocket;
end;

procedure TFTPSend.ParseRemote(Value: string);
var
  n: integer;
  nb, ne: integer;
  s: string;
  x: integer;
begin
  Value := trim(Value);
  nb := Pos('(',Value);
  ne := Pos(')',Value);
  if (nb = 0) or (ne = 0) then
  begin
    nb:=RPos(' ',Value);
    s:=Copy(Value, nb + 1, Length(Value) - nb);
  end
  else
  begin
    s:=Copy(Value,nb+1,ne-nb-1);
  end;
  for n := 1 to 4 do
    if n = 1 then
      FDataIP := Fetch(s, ',')
    else
      FDataIP := FDataIP + '.' + Fetch(s, ',');
  x := StrToIntDef(Fetch(s, ','), 0) * 256;
  x := x + StrToIntDef(Fetch(s, ','), 0);
  FDataPort := IntToStr(x);
end;

procedure TFTPSend.ParseRemoteEPSV(Value: string);
var
  n: integer;
  s, v: string;
begin
  s := SeparateRight(Value, '(');
  s := SeparateLeft(s, ')');
  Delete(s, Length(s), 1);
  v := '';
  for n := Length(s) downto 1 do
    if s[n] in ['0'..'9'] then
      v := s[n] + v
    else
      Break;
  FDataPort := v;
  FDataIP := FTargetHost;
end;

function TFTPSend.DataSocket: boolean;
var
  s: string;
begin
  Result := False;
  if FPassiveMode then
  begin
    if FSock.IP6used then
      s := '2'
    else
      s := '1';
    if (FTPCommand('EPSV ' + s) div 100) = 2 then
    begin
      ParseRemoteEPSV(FResultString);
    end
    else
      if FSock.IP6used then
        Exit
      else
      begin
        if (FTPCommand('PASV') div 100) <> 2 then
          Exit;
        ParseRemote(FResultString);
      end;
    FDSock.CloseSocket;
    FDSock.Bind(FIPInterface, cAnyPort);
    FDSock.Connect(FDataIP, FDataPort);
    Result := FDSock.LastError = 0;
  end
  else
  begin
    FDSock.CloseSocket;
    if FForceDefaultPort then
      s := cFtpDataProtocol
    else
      s := '0';
    //IP cannot be '0.0.0.0'!
    if FIPInterface = cAnyHost then
      FDSock.Bind(FDSock.LocalName, s)
    else
      FDSock.Bind(FIPInterface, s);
    if FDSock.LastError <> 0 then
      Exit;
    FDSock.SetLinger(True, 10);
    FDSock.Listen;
    FDSock.GetSins;
    FDataIP := FDSock.GetLocalSinIP;
    FDataIP := FDSock.ResolveName(FDataIP);
    FDataPort := IntToStr(FDSock.GetLocalSinPort);
    if IsIp6(FDataIP) then
      s := '2'
    else
      s := '1';
    s := 'EPRT |' + s +'|' + FDataIP + '|' + FDataPort + '|';
    Result := (FTPCommand(s) div 100) = 2;
    if not Result and IsIP(FDataIP) then
    begin
      s := ReplaceString(FDataIP, '.', ',');
      s := 'PORT ' + s + ',' + IntToStr(FDSock.GetLocalSinPort div 256)
        + ',' + IntToStr(FDSock.GetLocalSinPort mod 256);
      Result := (FTPCommand(s) div 100) = 2;
    end;
  end;
end;

function TFTPSend.AcceptDataSocket: Boolean;
var
  x: integer;
begin
  if FPassiveMode then
    Result := True
  else
  begin
    Result := False;
    if FDSock.CanRead(FTimeout) then
    begin
      x := FDSock.Accept;
      if not FDSock.UsingSocks then
        FDSock.CloseSocket;
      FDSock.Socket := x;
      Result := True;
    end;
  end;
  if Result and FIsDataTLS then
  begin
{$IFDEF STREAMSEC}
    if Assigned(FTLSServer) then
    begin
      FDSock.TLSServer := FTLSServer;
      FDSock.Connect('','');
      Result := FDSock.LastError = 0;
    end
    else
      Result := False;
{$ELSE}
    FDSock.SSLDoConnect;
    Result := FDSock.LastError = 0;
{$ENDIF}
  end;
end;

function TFTPSend.DataRead(const DestStream: TStream): Boolean;
var
  x: integer;
  buf: string;
begin
  Result := False;
  try
    if not AcceptDataSocket then
      Exit;
    repeat
      buf := FDSock.RecvPacket(FTimeout);
      if FDSock.LastError = 0 then
        DestStream.Write(Pointer(buf)^, Length(buf));
    until FDSock.LastError <> 0;
    FDSock.CloseSocket;
    x := ReadResult;
    Result := (x div 100) = 2;
  finally
    FDSock.CloseSocket;
  end;
end;

function TFTPSend.DataWrite(const SourceStream: TStream): Boolean;
const
  BufSize = 8192;
var
  Bytes: integer;
  bc, lb: integer;
  n, x: integer;
  Buf: string;
begin
  Result := False;
  try
    if not AcceptDataSocket then
      Exit;
    Bytes := SourceStream.Size - SourceStream.Position;
    bc := Bytes div BufSize;
    lb := Bytes mod BufSize;
    SetLength(Buf, BufSize);
    for n := 1 to bc do
    begin
      SourceStream.read(Pointer(buf)^, BufSize);
      FDSock.SendBuffer(Pchar(buf), BufSize);
      if FDSock.LastError <> 0 then
        Exit;
    end;
    SetLength(Buf, lb);
    SourceStream.read(Pointer(buf)^, lb);
    FDSock.SendBuffer(Pchar(buf), lb);
    if FDSock.LastError <> 0 then
      Exit;
    FDSock.CloseSocket;
    x := ReadResult;
    Result := (x div 100) = 2;
  finally
    FDSock.CloseSocket;
  end;
end;

function TFTPSend.List(Directory: string; NameList: Boolean): Boolean;
var
  x: integer;
  l: TStringList;
begin
  Result := False;
  FDataStream.Clear;
  FFTPList.Clear;
  if Directory <> '' then
    Directory := ' ' + Directory;
  if not DataSocket then
    Exit;
  FTPCommand('TYPE A');
  if NameList then
    x := FTPCommand('NLST' + Directory)
  else
    x := FTPCommand('LIST' + Directory);
  if (x div 100) <> 1 then
    Exit;
  Result := DataRead(FDataStream);
  if not NameList then
  begin
    l := TStringList.Create;
    try
      FDataStream.Seek(0, soFromBeginning);
      l.LoadFromStream(FDataStream);
      for x := 0 to l.Count - 1 do
        FFTPList.ParseLine(l[x]);
    finally
      l.Free;
    end;
  end;
  FDataStream.Seek(0, soFromBeginning);
end;

function TFTPSend.RetrieveFile(const FileName: string; Restore: Boolean): Boolean;
var
  RetrStream: TStream;
begin
  Result := False;
  if FileName = '' then
    Exit;
  Restore := Restore and FCanResume;
  if FDirectFile then
    if Restore and FileExists(FDirectFileName) then
      RetrStream := TFileStream.Create(FDirectFileName,
        fmOpenReadWrite  or fmShareExclusive)
    else
      RetrStream := TFileStream.Create(FDirectFileName,
        fmCreate or fmShareDenyWrite)
  else
    RetrStream := FDataStream;
  try
    if not DataSocket then
      Exit;
    if FBinaryMode then
      FTPCommand('TYPE I')
    else
      FTPCommand('TYPE A');
    if Restore then
    begin
      RetrStream.Seek(0, soFromEnd);
      if (FTPCommand('REST ' + IntToStr(RetrStream.Size)) div 100) <> 3 then
        Exit;
    end
    else
      if RetrStream is TMemoryStream then
        TMemoryStream(RetrStream).Clear;
    if (FTPCommand('RETR ' + FileName) div 100) <> 1 then
      Exit;
    Result := DataRead(RetrStream);
    if not FDirectFile then
      RetrStream.Seek(0, soFromBeginning);
  finally
    if FDirectFile then
      RetrStream.Free;
  end;
end;

function TFTPSend.InternalStor(const Command: string; RestoreAt: integer): Boolean;
var
  SendStream: TStream;
  StorSize: integer;
begin
  Result := False;
  if FDirectFile then
    if not FileExists(FDirectFileName) then
      Exit
    else
      SendStream := TFileStream.Create(FDirectFileName,
        fmOpenRead or fmShareDenyWrite)
  else
    SendStream := FDataStream;
  try
    if not DataSocket then
      Exit;
    if FBinaryMode then
      FTPCommand('TYPE I')
    else
      FTPCommand('TYPE A');
    StorSize := SendStream.Size;
    if not FCanResume then
      RestoreAt := 0;
    if RestoreAt = StorSize then
    begin
      Result := True;
      Exit;
    end;
    if RestoreAt > StorSize then
      RestoreAt := 0;
    FTPCommand('ALLO ' + IntToStr(StorSize - RestoreAt));
    if FCanResume then
      if (FTPCommand('REST ' + IntToStr(RestoreAt)) div 100) <> 3 then
        Exit;
    SendStream.Seek(RestoreAt, soFromBeginning);
    if (FTPCommand(Command) div 100) <> 1 then
      Exit;
    Result := DataWrite(SendStream);
  finally
    if FDirectFile then
      SendStream.Free;
  end;
end;

function TFTPSend.StoreFile(const FileName: string; Restore: Boolean): Boolean;
var
  RestoreAt: integer;
begin
  Result := False;
  if FileName = '' then
    Exit;
  RestoreAt := 0;
  Restore := Restore and FCanResume;
  if Restore then
  begin
    RestoreAt := Self.FileSize(FileName);
    if RestoreAt < 0 then
      RestoreAt := 0;
  end;
  Result := InternalStor('STOR ' + FileName, RestoreAt);
end;

function TFTPSend.StoreUniqueFile: Boolean;
begin
  Result := InternalStor('STOU', 0);
end;

function TFTPSend.AppendFile(const FileName: string): Boolean;
begin
  Result := False;
  if FileName = '' then
    Exit;
  Result := InternalStor('APPE '+FileName, 0);
end;

function TFTPSend.NoOp: Boolean;
begin
  Result := (FTPCommand('NOOP') div 100) = 2;
end;

function TFTPSend.RenameFile(const OldName, NewName: string): Boolean;
begin
  Result := False;
  if (FTPCommand('RNFR ' + OldName) div 100) <> 3  then
    Exit;
  Result := (FTPCommand('RNTO ' + NewName) div 100) = 2;
end;

function TFTPSend.DeleteFile(const FileName: string): Boolean;
begin
  Result := (FTPCommand('DELE ' + FileName) div 100) = 2;
end;

function TFTPSend.FileSize(const FileName: string): integer;
var
  s: string;
begin
  Result := -1;
  if (FTPCommand('SIZE ' + FileName) div 100) = 2 then
  begin
    s := SeparateRight(ResultString, ' ');
    s := SeparateLeft(s, ' ');
    Result := StrToIntDef(s, -1);
  end;
end;

function TFTPSend.ChangeWorkingDir(const Directory: string): Boolean;
begin
  Result := (FTPCommand('CWD ' + Directory) div 100) = 2;
end;

function TFTPSend.ChangeToRootDir: Boolean;
begin
  Result := (FTPCommand('CDUP') div 100) = 2;
end;

function TFTPSend.DeleteDir(const Directory: string): Boolean;
begin
  Result := (FTPCommand('RMD ' + Directory) div 100) = 2;
end;

function TFTPSend.CreateDir(const Directory: string): Boolean;
begin
  Result := (FTPCommand('MKD ' + Directory) div 100) = 2;
end;

function TFTPSend.GetCurrentDir: String;
begin
  Result := '';
  if (FTPCommand('PWD') div 100) = 2 then
  begin
    Result := SeparateRight(FResultString, '"');
    Result := Separateleft(Result, '"');
  end;
end;

procedure TFTPSend.Abort;
begin
  FDSock.AbortSocket;
end;

{==============================================================================}

constructor TFTPList.Create;
begin
  inherited Create;
  FList := TList.Create;
end;

destructor TFTPList.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

procedure TFTPList.Clear;
var
  n:integer;
begin
  for n := 0 to FList.Count - 1 do
    if Assigned(FList[n]) then
      TFTPListRec(FList[n]).Free;
  FList.Clear;
end;

// based on idea by D. J. Bernstein, djb@pobox.com
// fixed UNIX style decoding by Alex, akudrin@rosbi.ru
function TFTPList.ParseLine(Value: string): Boolean;
var
  flr: TFTPListRec;
  s: string;
  state: integer;
  year: Word;
  month: Word;
  mday: Word;
  t: TDateTime;
  x: integer;
  al_tmp : array[1..2] of string; // alex
begin
  Result := False;
  if Length(Value) < 2 then
    Exit;

  year := 0;
  month := 0;
  mday := 0;
  t := 0;
  flr := TFTPListRec.Create;
  try
    flr.FileName := '';
    flr.Directory := False;
    flr.Readable := False;
    flr.FileSize := 0;
    flr.FileTime := 0;
    Value := Trim(Value);
  {EPLF
    See http://pobox.com/~djb/proto/eplf.txt
  "+i8388621.29609,m824255902,/," + #9 + "tdev"
  "+i8388621.44468,m839956783,r,s10376," + #9 + "RFCEPLF" }
    if Value[1] = '+' then
    begin
      s := Fetch(Value, ',');
      while s <> '' do
      begin
        if s[1] = #9 then
        begin
          flr.FileName := Copy(s, 2, Length(s) - 1);
          Result := True;
        end;
        case s[1] of
          '/':
            flr.Directory := true;
          'r':
            flr.Readable := true;
          's':
            flr.FileSize := StrToIntDef(Copy(s, 2, Length(s) - 1), 0);
          'm':
            flr.FileTime := (StrToIntDef(Copy(s, 2, Length(s) - 1), 0) / 86400)
              + 25569;
        end;
        s := Fetch(Value, ',');
      end;
      Exit;
    end;

  {UNIX-style listing, without inum and without blocks
   Permissions   Owner     Group        Size  Date/Time   Name

  "-rw-r--r--   1 root     other        531 Jan 29 03:26 README"
  "dr-xr-xr-x   2 root     other        512 Apr  8  1994 etc"
  "dr-xr-xr-x   2 root                  512 Apr  8  1994 etc"
  "lrwxrwxrwx   1 root     other        7   Jan 25 00:17 bin -> usr/bin"

    Also produced by Microsoft's FTP servers for Windows:
  "----------   1 owner    group         1803128 Jul 10 10:18 ls-lR.Z"

  Also WFTPD for MSDOS:
  "-rwxrwxrwx   1 noone    nogroup      322 Aug 19  1996 message.ftp"

  Also NetWare:
  "d [R----F--] supervisor            512       Jan 16 18:53    login"
  "- [R----F--] rhesus             214059       Oct 20 15:27    cx.exe"

  Also NetPresenz for the Mac:
  "-------r--         326  1391972  1392298 Nov 22  1995 MegaPhone.sit"
  "drwxrwxr-x               folder        2 May 10  1996 network" }

    if (Value[1] = 'b') or
       (Value[1] = 'c') or
       (Value[1] = 'd') or
       (Value[1] = 'l') or
       (Value[1] = 'p') or
       (Value[1] = 's') or
       (Value[1] = '-') then
    begin

      // alex begin
      // default year
      DecodeDate(date,year,month,mday);  // alex
      month:=0;
      mday :=0;

      if Value[1] = 'd'      then flr.Directory := True
      else if Value[1] = '-' then flr.Readable := True
      else if Value[1] = 'l' then
      begin
        flr.Directory := True;
        flr.Readable := True;
      end;

      state:=1;
      s := Fetch(Value, ' ');
      while s<>'' do
      begin
          month:=GetMonthNumber(s);
          if month>0 then
             break;
          al_tmp[state]:=s;
          if state=1 then state:=2
          else            state:=1;
          s := Fetch(Value, ' ');
      end;
      if month>0 then begin
         if state=1 then
              flr.FileSize := StrToIntDef(al_tmp[2], 0)
         else flr.FileSize := StrToIntDef(al_tmp[1], 0);

         state:=1;
         s := Fetch(Value, ' ');
         while s <> '' do
         begin
              case state of
                 1 : mday := StrToIntDef(s, 0);
                 2 : begin
                       if (Pos(':', s) > 0) then
                          t := GetTimeFromStr(s)
                       else if Length(s) = 4 then
                          year := StrToIntDef(s, 0)
                       else Exit;
                       if (year = 0) or (month = 0) or (mday = 0) then
                           Exit;
                       // for date 2-29 find last leap year. (fix for non-existent year)
                       if (month = 2) and (mday = 29) then
                         while not IsLeapYear(year) do
                           Dec(year);
                       flr.FileTime := t + Encodedate(year, month, mday);
                     end;
                 3 : begin
                       if Value <> '' then
                         s := s + ' ' + Value;
                       s := SeparateLeft(s, ' -> ');
                       flr.FileName := s;
                       Result := True;
                       break;
                     end;
              end;
              inc(state);
              s := Fetch(Value, ' ');
         end;
      end;
      // alex end
      exit;
    end;
  {Microsoft NT 4.0 FTP Service
  10-20-98  08:57AM               619098 rizrem.zip
  11-12-98  11:54AM       <DIR>          test         }
    if (Value[1] = '1') or (Value[1] = '0') then
    begin
      if Length(Value) < 8 then
        Exit;
      if (Ord(Value[2]) < 48) or (Ord(Value[2]) > 57) then
        Exit;
      if Value[3] <> '-' then
        Exit;
      s := Fetch(Value, ' ');
      t := GetDateMDYFromStr(s);
      if t = 0 then
        Exit;
      if Value = '' then
        Exit;
      s := Fetch(Value, ' ');
      flr.FileTime := t + GetTimeFromStr(s);
      if Value = '' then
        Exit;
      s := Fetch(Value, ' ');
      if s[1] = '<' then
        flr.Directory := True
      else
      begin
        flr.Readable := true;
        flr.FileSize := StrToIntDef(s, 0);
      end;
      if Value = '' then
        Exit;
      flr.FileName := Trim(Value);
      Result := True;
      Exit;
    end;
  {MultiNet
  "00README.TXT;1      2 30-DEC-1996 17:44 [SYSTEM] (RWED,RWED,RE,RE)"
  "CORE.DIR;1          1  8-SEP-1996 16:09 [SYSTEM] (RWE,RWE,RE,RE)"

  and non-MutliNet VMS:
  "CII-MANUAL.TEX;1  213/216  29-JAN-1996 03:33:12  [ANONYMOU,ANONYMOUS]   (RWED,RWED,,)" }
    x := Pos(';', Value);
    if x > 0 then
    begin
      s := Fetch(Value, ';');
      if Uppercase(Copy(s,Length(s) - 4, 4)) = '.DIR' then
      begin
        flr.FileName := Copy(s, 1, Length(s) - 4);
        flr.Directory := True;
      end
      else
      begin
        flr.FileName := s;
        flr.Readable := True;
      end;
      s := Fetch(Value, ' ');
      s := Fetch(Value, ' ');
      if Value = '' then
        Exit;
      s := Fetch(Value, '-');
      mday := StrToIntDef(s, 0);
      s := Fetch(Value, '-');
      month := GetMonthNumber(s);
      s := Fetch(Value, ' ');
      year := StrToIntDef(s, 0);
      s := Fetch(Value, ' ');
      if Value = '' then
        Exit;
      if (year = 0) or (month = 0) or (mday = 0) then
        Exit;
      flr.FileTime := GetTimeFromStr(s) + EncodeDate(year, month, mday);
      Result := True;
      Exit;
    end;
  finally
    if Result then
      if flr.Directory and ((flr.FileName = '.') or (flr.FileName = '..')) then
        Result := False;
    if Result then
      FList.Add(flr)
    else
      flr.Free;
  end;
end;

{==============================================================================}

function FtpGetFile(const IP, Port, FileName, LocalFile,
  User, Pass: string): Boolean;
begin
  Result := False;
  with TFTPSend.Create do
  try
    if User <> '' then
    begin
      Username := User;
      Password := Pass;
    end;
    TargetHost := IP;
    TargetPort := Port;
    if not Login then
      Exit;
    DirectFileName := LocalFile;
    DirectFile:=True;
    Result := RetrieveFile(FileName, False);
    Logout;
  finally
    Free;
  end;
end;

function FtpPutFile(const IP, Port, FileName, LocalFile,
  User, Pass: string): Boolean;
begin
  Result := False;
  with TFTPSend.Create do
  try
    if User <> '' then
    begin
      Username := User;
      Password := Pass;
    end;
    TargetHost := IP;
    TargetPort := Port;
    if not Login then
      Exit;
    DirectFileName := LocalFile;
    DirectFile:=True;
    Result := StoreFile(FileName, False);
    Logout;
  finally
    Free;
  end;
end;

function FtpInterServerTransfer(
  const FromIP, FromPort, FromFile, FromUser, FromPass: string;
  const ToIP, ToPort, ToFile, ToUser, ToPass: string): Boolean;
var
  FromFTP, ToFTP: TFTPSend;
  s: string;
  x: integer;
begin
  Result := False;
  FromFTP := TFTPSend.Create;
  toFTP := TFTPSend.Create;
  try
    if FromUser <> '' then
    begin
      FromFTP.Username := FromUser;
      FromFTP.Password := FromPass;
    end;
    if ToUser <> '' then
    begin
      ToFTP.Username := ToUser;
      ToFTP.Password := ToPass;
    end;
    FromFTP.TargetHost := FromIP;
    FromFTP.TargetPort := FromPort;
    ToFTP.TargetHost := ToIP;
    ToFTP.TargetPort := ToPort;
    if not FromFTP.Login then
      Exit;
    if not ToFTP.Login then
      Exit;
    if (FromFTP.FTPCommand('PASV') div 100) <> 2 then
      Exit;
    FromFTP.ParseRemote(FromFTP.ResultString);
    s := ReplaceString(FromFTP.DataIP, '.', ',');
    s := 'PORT ' + s + ',' + IntToStr(StrToIntDef(FromFTP.DataPort, 0) div 256)
      + ',' + IntToStr(StrToIntDef(FromFTP.DataPort, 0) mod 256);
    if (ToFTP.FTPCommand(s) div 100) <> 2 then
      Exit;
    x := ToFTP.FTPCommand('RETR ' + FromFile);
    if (x div 100) <> 1 then
      Exit;
    x := FromFTP.FTPCommand('STOR ' + ToFile);
    if (x div 100) <> 1 then
      Exit;
    FromFTP.Timeout := 21600000;
    x := FromFTP.ReadResult;
    if (x  div 100) <> 2 then
      Exit;
    ToFTP.Timeout := 21600000;
    x := ToFTP.ReadResult;
    if (x div 100) <> 2 then
      Exit;
    Result := True;
  finally
    ToFTP.Free;
    FromFTP.Free;
  end;
end;

end.
