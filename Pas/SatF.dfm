object SatForm: TSatForm
  Left = 340
  Top = 225
  Width = 308
  Height = 400
  Caption = 'Satellites'
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnHide = FormHide
  OnResize = FormResize
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object ElevationCheckBox: TCheckBox
    Left = 8
    Top = 336
    Width = 97
    Height = 17
    Caption = 'Use &Elevation'
    Checked = True
    Color = clWhite
    ParentColor = False
    State = cbChecked
    TabOrder = 0
  end
  object RotationCheckBox: TCheckBox
    Left = 8
    Top = 352
    Width = 113
    Height = 17
    Caption = '&Rotate Accordingly'
    Checked = True
    State = cbChecked
    TabOrder = 1
  end
  object SatTimer: TTimer
    Enabled = False
    Interval = 333
    OnTimer = SatTimerTimer
    Left = 8
    Top = 8
  end
end
