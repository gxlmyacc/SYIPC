object Form2: TForm2
  Left = 334
  Top = 133
  BorderStyle = bsSingle
  Caption = 'IPC'#26381#21153#31471
  ClientHeight = 447
  ClientWidth = 623
  Color = clBtnFace
  Font.Charset = ANSI_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = #23435#20307
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 12
  object lbl1: TLabel
    Left = 10
    Top = 15
    Width = 60
    Height = 12
    Caption = #22238#35805#21517#31216#65306
  end
  object lbl2: TLabel
    Left = 10
    Top = 270
    Width = 36
    Height = 12
    Caption = #26085#24535#65306
  end
  object lbl3: TLabel
    Left = 10
    Top = 35
    Width = 84
    Height = 12
    Caption = #36830#25509#30340#23458#25143#31471#65306
  end
  object edtSessionName: TEdit
    Left = 80
    Top = 11
    Width = 376
    Height = 20
    TabOrder = 2
    Text = 'SYIPC.DEMO'
  end
  object btnOpen: TButton
    Left = 540
    Top = 9
    Width = 75
    Height = 25
    Caption = #21019#24314
    TabOrder = 1
    OnClick = btnOpenClick
  end
  object memContent: TMemo
    Left = 155
    Top = 40
    Width = 461
    Height = 181
    ScrollBars = ssVertical
    TabOrder = 3
  end
  object btnSend: TButton
    Left = 495
    Top = 230
    Width = 121
    Height = 25
    Caption = #21457#36865
    TabOrder = 8
    OnClick = btnSendClick
  end
  object memLog: TMemo
    Left = 10
    Top = 290
    Width = 606
    Height = 151
    ScrollBars = ssVertical
    TabOrder = 9
  end
  object lstClient: TListBox
    Left = 10
    Top = 55
    Width = 136
    Height = 201
    ItemHeight = 12
    TabOrder = 4
  end
  object btnBroadcast: TButton
    Left = 155
    Top = 230
    Width = 101
    Height = 25
    Caption = #24191#25773
    TabOrder = 5
    OnClick = btnBroadcastClick
  end
  object btn1: TButton
    Left = 260
    Top = 230
    Width = 101
    Height = 25
    Caption = #21457#36865'5000'#26465
    TabOrder = 6
    OnClick = btn1Click
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
    Left = 370
    Top = 230
    Width = 116
    Height = 25
    Caption = #35843#29992'ShowMessage'
    TabOrder = 7
    OnClick = btnCallShowMessageClick
  end
end
