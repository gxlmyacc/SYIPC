unit Unit2;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, SYIPCIntf, StdCtrls;

type
  TForm2 = class(TForm)
    edtSessionName: TEdit;
    lbl1: TLabel;
    btnOpen: TButton;
    memContent: TMemo;
    btnSend: TButton;
    lbl2: TLabel;
    memLog: TMemo;
    lstClient: TListBox;
    lbl3: TLabel;
    btnBroadcast: TButton;
    btn1: TButton;
    btnBindEvent: TButton;
    btnCallShowMessage: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnOpenClick(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnBroadcastClick(Sender: TObject);
    procedure btn1Click(Sender: TObject);
    procedure btnBindEventClick(Sender: TObject);
    procedure btnCallShowMessageClick(Sender: TObject);
  private
    FIPCServer: IIPCServer;
  public
    procedure DoServerMessage(const AServer: IIPCServer; const AState: TIPCState;
      const ASenderID: Cardinal; const AMessage: IIPCMessage);
  end;

  {$METHODINFO ON}
  TIPCServerTest = class
  public
    function ShowMessage(const AMsg: WideString): Boolean;
  end;
  {$METHODINFO OFF}

var
  Form2: TForm2;

implementation

{$R *.dfm}

uses
  ObjComAuto;

procedure TForm2.FormCreate(Sender: TObject);
begin
  FIPCServer := CreateIPCServer(edtSessionName.Text);
  FIPCServer.OnMessage := DoServerMessage;
  FIPCServer.Dispatch := TObjectDispatch.Create(TIPCServerTest.Create);
end;

procedure TForm2.FormDestroy(Sender: TObject);
begin
  FIPCServer := nil;
end;

procedure TForm2.btnOpenClick(Sender: TObject);
begin
  if btnOpen.Caption = '创建' then
  begin
    if not FIPCServer.Open(edtSessionName.Text) then
      ShowMessage('创建会话失败:'+FIPCServer.LastError);
  end
  else
  begin
    FIPCServer.Close;
  end;
end;

procedure TForm2.DoServerMessage(const AServer: IIPCServer;
  const AState: TIPCState; const ASenderID: Cardinal;
  const AMessage: IIPCMessage);
var
  idx: Integer;
begin
  Assert(MainThreadID = GetCurrentThreadId);
  case AState of
    isAfterOpen:
    begin
      memLog.Lines.Add('DoServerMessage.isAfterOpen:' + IntToStr(AServer.SessionHandle));
      btnOpen.Caption := '关闭';
    end;
    isAfterClose:
    begin
      memLog.Lines.Add('DoServerMessage.isAfterClose');
      btnOpen.Caption := '创建';
    end;
    isConnect:
    begin
      memLog.Lines.Add('DoServerMessage.isConnect');
      if lstClient.Items.IndexOf(IntToStr(ASenderID)) < 0 then
        lstClient.Items.Add(IntToStr(ASenderID));
    end;
    isDisconnect:
    begin
      memLog.Lines.Add('DoServerMessage.isDisconnect');
      idx := lstClient.Items.IndexOf(IntToStr(ASenderID));
      if idx >= 0 then
        lstClient.Items.Delete(idx);
    end;       
    isReceiveData://该状态的处理处在主线程(默认)或一个独立的线程中(Server/Client的ReciveMessageInThread=True)
    begin
      memLog.Lines.Add('DoServerMessage.isReceiveData');
      case AMessage.DataType of
        mdtUnknown:
          memLog.Lines.Add('自定义数据');
        mdtString:
          memLog.Lines.Add('字符串：' + AMessage.S);
        mdtInteger:
          memLog.Lines.Add('整数:' + IntToStr(AMessage.I));
        mdtDouble:
          memLog.Lines.Add('浮点数:' + FloatToStr(AMessage.D));
        mdtCurrency:
          memLog.Lines.Add('金额:' + FloatToStr(AMessage.C));
        mdtDateTime:
          memLog.Lines.Add('日期:' + DateTimeToStr(AMessage.DT));
      end;
    end;
  end;
end;

procedure TForm2.btnSendClick(Sender: TObject);
var
  LClientID: Cardinal;
  iResult: Boolean;
begin
  if not FIPCServer.Active then
  begin
    ShowMessage('会话尚未创建！');
    Exit;
  end;
  if lstClient.ItemIndex < 0 then
  begin
    ShowMessage('请在左侧选择一个待交互的客户端！');
    Exit;
  end;
  LClientID := StrToInt(lstClient.Items[lstClient.ItemIndex]);
  iResult := FIPCServer.Send(LClientID, memContent.Lines.Text);
  memLog.Lines.Add(Format('发送结果:%s', [BoolToStr(iResult, True)]));
end;

procedure TForm2.btnBroadcastClick(Sender: TObject);
var
  iResult: Boolean;
begin                
  if not FIPCServer.Active then
  begin
    ShowMessage('会话尚未创建！');
    Exit;
  end;
  iResult := FIPCServer.Broadcast(memContent.Lines.Text);
  memLog.Lines.Add(Format('发送结果:%s', [BoolToStr(iResult, True)]));
end;

procedure TForm2.btn1Click(Sender: TObject);
var
  i: Integer;
  LClientID: Cardinal;
  tick: Cardinal;
begin
  if not FIPCServer.Active then
  begin
    ShowMessage('会话尚未创建！');
    Exit;
  end;
  if lstClient.ItemIndex < 0 then
  begin
    ShowMessage('请在左侧选择一个待交互的客户端！');
    Exit;
  end;
  LClientID := StrToInt(lstClient.Items[lstClient.ItemIndex]);
  tick := GetTickCount;
  for i := 0 to 5000 do
  begin
    FIPCServer.Send(LClientID, memContent.Lines.Text + '_' + IntToStr(i));
  end;
  tick := GetTickCount - tick;
  memLog.Lines.Add('耗时：' + IntToStr(tick));
end;

procedure TForm2.btnBindEventClick(Sender: TObject);
begin
  if btnBindEvent.Caption = '绑定事件' then
  begin
    FIPCServer.OnMessage := DoServerMessage;
    btnBindEvent.Caption := '解绑事件';
  end
  else
  begin
    FIPCServer.OnMessage := nil;
    btnBindEvent.Caption := '绑定事件';
  end;
end;

{ TIPCServerTest }

function TIPCServerTest.ShowMessage(const AMsg: WideString): Boolean;
begin
  Form2.memLog.Lines.Add('[TIPCServerTest.ShowMessage]'+AMsg);
  Result := True;
end;

procedure TForm2.btnCallShowMessageClick(Sender: TObject);
var
  LClientID: Cardinal;
  LResult: IIPCMessage;
begin
  if not FIPCServer.Active then
  begin
    ShowMessage('会话尚未创建！');
    Exit;
  end;
  if lstClient.ItemIndex < 0 then
  begin
    ShowMessage('请在左侧选择一个待交互的客户端！');
    Exit;
  end;
  LClientID := StrToInt(lstClient.Items[lstClient.ItemIndex]);
  LResult := FIPCServer.Call(LClientID, 'ShowMessage', [memContent.Lines.Text]);
  memLog.Lines.Add(Format('调用结果:%s', [LResult.S]));
end;

end.
