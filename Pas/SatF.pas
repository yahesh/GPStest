unit SatF;

interface

uses
  Windows,
  SysUtils,
  SyncObjs,
  StdCtrls,
  Math,
  Graphics,
  Forms,
  ExtCtrls,
  Controls,
  Classes,
  GPSdataU;

type
  TSatForm = class(TForm)
    ElevationCheckBox : TCheckBox;
    RotationCheckBox  : TCheckBox;
    SatTimer          : TTimer;

    procedure FormCreate(Sender : TObject);
    procedure FormDestroy(Sender : TObject);
    procedure FormHide(Sender : TObject);
    procedure FormResize(Sender : TObject);
    procedure FormShow(Sender : TObject);
    procedure SatTimerTimer(Sender : TObject);
  private
    { Private-Deklarationen }
    FCriticalSection : TCriticalSection;
    FFixes           : array of String;
    FSatellites      : array of TGSVsatellite;

    procedure PrintScreen;
  public
    { Public-Deklarationen }
    procedure SetFixes(const AFixes : array of String);
    procedure SetSatellites(const ASatellites : array of TGSVsatellite; const AIndex : Byte);
  end;

var
  SatForm: TSatForm;

implementation

{$R *.dfm}

{ TSatForm }

procedure TSatForm.FormCreate(Sender : TObject);
begin
  FCriticalSection := TCriticalSection.Create;
end;

procedure TSatForm.FormDestroy(Sender : TObject);
begin
  FCriticalSection.Free;
end;

procedure TSatForm.FormHide(Sender : TObject);
begin
  SatTimer.Enabled := false;
end;

procedure TSatForm.FormResize(Sender : TObject);
begin
  FCriticalSection.Enter;
  try
    ElevationCheckBox.Left := 5;
    ElevationCheckBox.Top  := ClientHeight - ElevationCheckBox.Height - RotationCheckBox.Height - 5;
    RotationCheckBox.Left  := 5;
    RotationCheckBox.Top   := ClientHeight - RotationCheckBox.Height - 5;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TSatForm.FormShow(Sender : TObject);
begin
  SatTimer.Enabled := true;
end;

procedure TSatForm.SatTimerTimer(Sender : TObject);
begin
  SatTimer.Enabled := false;
  try
    PrintScreen;
  finally
    SatTimer.Enabled := true;
  end;
end;

procedure TSatForm.PrintScreen;
  function CenterToPos(const ACenter : TPoint; const ARadius : LongInt) : TPoint;
  begin
    Result.X := ClientWidth - ARadius - 25 + ACenter.X;
    Result.Y := ClientHeight - ARadius - 25 + ACenter.Y;
  end;
const
  CMaxElevation = 90;
var
  LDifference   : LongInt;
  LFix          : Boolean;
  LIndex        : LongInt;
  LIndex2       : LongInt;
  LPosA         : TPoint;
  LPosB         : TPoint;
  LPosition     : TPoint;
  LRadius       : LongInt;
  LSide         : LongInt;
  LSNR          : LongInt;
  LValue        : LongInt;
begin
  FCriticalSection.Enter;
  try
    if (ClientWidth < ClientHeight) then
      LSide := ClientWidth
    else
      LSide := ClientHeight;
    LRadius := Trunc(LSide/2 - 50);

    // empty screen
    Canvas.FillRect(Rect(0, 0, Pred(ClientWidth), Pred(ClientHeight)));

    // draw circle
    LPosA := CenterToPos(Point(- LRadius, - LRadius), LRadius);
    LPosB := CenterToPos(Point(+ LRadius, + LRadius), LRadius);
    Canvas.Ellipse(LPosA.X, LPosA.Y, LPosB.X, LPosB.Y);

    // draw center cross
    LPosA := CenterToPos(Point(- 5, 0), LRadius);
    Canvas.MoveTo(LPosA.X, LPosA.Y);
    LPosA := CenterToPos(Point(+ 6, 0), LRadius);
    Canvas.LineTo(LPosA.X, LPosA.Y);
    LPosA := CenterToPos(Point(0, - 5), LRadius);
    Canvas.MoveTo(LPosA.X, LPosA.Y);
    LPosA := CenterToPos(Point(0, + 6), LRadius);
    Canvas.LineTo(LPosA.X, LPosA.Y);

    for LIndex := 0 to Pred(Length(FSatellites)) do
    begin
      if TryStrToInt(FSatellites[LIndex].Azimuth, LValue) then
      begin
        if not(TryStrToInt(FSatellites[LIndex].SNR, LSNR)) then
          LSNR := 0;

        if RotationCheckBox.Checked then
          LValue := - LValue + 90;

        // calculate position of satellite
        LPosition := CenterToPos(Point(Trunc(Cos(DegToRad(LValue)) * LRadius),
                                       Trunc(- Sin(DegToRad(LValue)) * LRadius)), LRadius);

        if ElevationCheckBox.Checked then
        begin
          // take satellite elevation into account
          if TryStrToInt(FSatellites[LIndex].Elevation, LValue) then
          begin
            LPosA := CenterToPos(Point(0, 0), LRadius);

            LDifference := Trunc(Abs((LPosition.X - LPosA.X) / LRadius) * (LRadius / CMaxElevation) * LValue);
            if (LPosition.X < LPosA.X) then
              LPosition.X := LPosition.X + LDifference
            else
              LPosition.X := LPosition.X - LDifference;

            LDifference := Trunc(Abs((LPosition.Y - LPosA.Y) / LRadius) * (LRadius / CMaxElevation) * LValue);
            if (LPosition.Y < LPosA.Y) then
              LPosition.Y := LPosition.Y + LDifference
            else
              LPosition.Y := LPosition.Y - LDifference;
          end;
        end;

        // check whether satellite is fixed
        LFix := false;
        for LIndex2 := 0 to Pred(Length(FFixes)) do
        begin
          LFix := (FSatellites[LIndex].PRN = FFixes[LIndex2]);
          if LFix then
            Break;
        end;

        // write satellite name to signal strength bar
        Canvas.TextOut(10, 10 + 20 * LIndex, FSatellites[LIndex].PRN);

        // draw satellite signal strength maximum
        Canvas.MoveTo(130, 10 + 20 * LIndex);
        Canvas.LineTo(130, 10 + 20 * LIndex + 15);

        // write signal strength to bar
        Canvas.TextOut(135, 10 + 20 * LIndex, FSatellites[LIndex].SNR);

        // set satellite colour depending on fixed status
        if LFix then
          Canvas.Brush.Color := clGreen
        else
          Canvas.Brush.Color := clRed;

        // draw satellite
        Canvas.Ellipse(LPosition.X - 10, LPosition.Y - 10, LPosition.X + 10, LPosition.Y + 10);
        Canvas.TextOut(LPosition.X - 7, LPosition.Y - 7, FSatellites[LIndex].PRN);

        // draw satellite signal strength bar
        Canvas.Rectangle(30 + LSNR, 10 + 20 * LIndex, 30, 10 + 20 * LIndex + 15);

        // reset colour
        Canvas.Brush.Color := clWhite;
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TSatForm.SetFixes(const AFixes : array of String);
var
  LIndex : LongInt;
begin
  FCriticalSection.Enter;
  try
    SetLength(FFixes, Length(AFixes));
    for LIndex := 0 to Pred(Length(FFixes)) do
      FFixes[LIndex] := AFixes[LIndex];
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TSatForm.SetSatellites(const ASatellites : array of TGSVsatellite; const AIndex : Byte);
var
  LCount  : LongInt;
  LFound  : Boolean;
  LIndex  : LongInt;
  LIndexB : LongInt;
begin
  FCriticalSection.Enter;
  try
    if (AIndex = 1) then
    begin
      SetLength(FSatellites, Length(ASatellites));
      for LIndex := 0 to Pred(Length(ASatellites)) do
        FSatellites[LIndex] := ASatellites[LIndex];
    end
    else
    begin
      SetLength(FSatellites, Length(FSatellites) + Length(ASatellites));
      LCount := 0;
      try
        for LIndex := 0 to Pred(Length(ASatellites)) do
        begin
          LFound := false;

          for LIndexB := 0 to Pred(Length(FSatellites) - Length(ASatellites)) do
          begin
            LFound := (FSatellites[LIndexB].PRN = ASatellites[LIndex].PRN);
            if LFound then
            begin
              FSatellites[LIndexB] := ASatellites[LIndex];

              Break;
            end;
          end;

          if not(LFound) then
          begin
            FSatellites[Length(FSatellites) - Length(ASatellites) + LCount] := ASatellites[LIndex];
            Inc(LCount);
          end;
        end;
      finally
        SetLength(FSatellites, Length(FSatellites) - Length(ASatellites) + LCount);
      end;
    end;
  finally
    FCriticalSection.Leave;
  end;
end;

end.
