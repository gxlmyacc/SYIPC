object Form1: TForm1
  Left = 295
  Top = 158
  Width = 640
  Height = 442
  Caption = 'IPC'#23458#25143#31471
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object lbl1: TLabel
    Left = 10
    Top = 15
    Width = 60
    Height = 13
    Caption = #20250#35805#21517#31216#65306
  end
  object lbl2: TLabel
    Left = 10
    Top = 270
    Width = 36
    Height = 13
    Caption = #26085#24535#65306
  end
  object edtSessionName: TEdit
    Left = 80
    Top = 11
    Width = 376
    Height = 21
    TabOrder = 2
    Text = 'SYIPC.DEMO'
  end
  object btnOpen: TButton
    Left = 540
    Top = 9
    Width = 75
    Height = 25
    Caption = #25171#24320
    TabOrder = 1
    OnClick = btnOpenClick
  end
  object memContent: TMemo
    Left = 10
    Top = 40
    Width = 606
    Height = 181
    ScrollBars = ssVertical
    TabOrder = 3
  end
  object btnSend: TButton
    Left = 415
    Top = 225
    Width = 206
    Height = 25
    Caption = #21457#36865
    TabOrder = 6
    OnClick = btnSendClick
  end
  object memLog: TMemo
    Left = 10
    Top = 256
    Width = 606
    Height = 145
    ScrollBars = ssVertical
    TabOrder = 7
  end
  object btnBindEvent: TButton
    Left = 470
    Top = 9
    Width = 65
    Height = 25
    Caption = #35299#32465#20107#20214
    TabOrder = 0
    OnClick = btnBindEventClick
  end
  object btnCallShowMessage: TButton
    Left = 200
    Top = 225
    Width = 206
    Height = 25
    Caption = #35843#29992'ShowMessage'
    TabOrder = 5
    OnClick = btnCallShowMessageClick
  end
  object btn1: TButton
    Left = 10
    Top = 225
    Width = 186
    Height = 25
    Caption = #21457#36865'1000'#26465
    TabOrder = 4
    OnClick = btn1Click
  end
end
