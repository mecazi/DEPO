unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, Unix, BaseUnix, process, FileUtil;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    MemoBetikler: TMemo;
    Memo2: TMemo;
    Memo3: TMemo;
    Memo4: TMemo;
    Memo5: TMemo;
    OpenDialog1: TOpenDialog;
    PageControl1: TPageControl;
    Panel1: TPanel;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    TabSheet3: TTabSheet;
    TabSheet4: TTabSheet;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Memo3Change(Sender: TObject);
    procedure Memo5Change(Sender: TObject);
    procedure MemoBetiklerChange(Sender: TObject);
    procedure PageControl1Change(Sender: TObject);
  private
    function ZstToXzDonustur(const CalismaDizini: string): Boolean;
    function RunCommandAndGetOutput(Command: string): string;
    function DebianToPisi(DebName: string): string;
    function ReadFileToString(FilePath: string): string;
  public

  end;

var
  Form1: TForm1;
  K:LongInt;
  AppPath,DebDosyasi,Komut,Cikti: string;
  HamListe, TemizListe, Paket: string;
  Parcalar: TStringArray;
  i: Integer;
  Paketler: TStringArray;
  PisiPaket, SonucXML: string;
  Liste: TStringList;
  PaketAdi: string;
  AProcess: TProcess;
  Baslik: string;
  DebPath, AyiklamaKlasoru: string;
  FullXML, ActionsFile: TStringList;
  HedefKlasor: string;
implementation

{$R *.lfm}

{ TForm1 }
function TForm1.ZstToXzDonustur(const CalismaDizini: string): Boolean;
var
  ZstDosyasi, XzDosyasi, GeciciKlasor: string;
begin
  Result := False;
  ZstDosyasi := CalismaDizini + '/data.tar.zst';
  XzDosyasi := CalismaDizini + '/data.tar.xz';
  GeciciKlasor := CalismaDizini + '/gecici_ayiklama';

  // 1. Kontrol: Ortada bir zst dosyası var mı?
  if not FileExists(ZstDosyasi) then
  begin
    // Eğer dosya zaten xz ise (bazı deb paketleri gibi), işleme gerek yok
    if FileExists(XzDosyasi) then Exit(True);
    Memo4.Lines.Add('Hata: Dönüştürülecek .zst dosyası bulunamadı!');
    Exit(False);
  end;

  try
    Memo4.Lines.Add('Dönüştürme işlemi başlıyor (zst -> xz)...');

    // 2. Temizlik: Eski kalıntıları temizle ve klasör oluştur
    fpSystem(PChar('rm -rf ' + GeciciKlasor));
    fpSystem(PChar('mkdir -p ' + GeciciKlasor));

    // 3. Ayıklama: .zst içeriğini geçici klasöre aç
    Memo4.Lines.Add('Adım 1: zst içeriği dışarı aktarılıyor...'); Application.ProcessMessages; // Arayüzü tazele!
    if fpSystem(PChar('tar --zstd -xf ' + ZstDosyasi + ' -C ' + GeciciKlasor)) <> 0 then
    begin
      Memo4.Lines.Add('Hata: zst ayıklanamadı! Sistemde "zstd" kurulu mu?');
      Exit(False);
    end;

    // 4. Yeniden Paketleme: İçeriği XZ (J parametresi) olarak paketle
    Memo4.Lines.Add('Adım 2: xz formatında sıkıştırılıyor (Bu biraz sürebilir)...'); Application.ProcessMessages; // Arayüzü tazele!
    // Not: 'cd' komutuyla klasöre girip paketlemek, dosya yollarının doğru olması için kritiktir.
    if fpSystem(PChar('cd ' + GeciciKlasor + ' && tar -cJf ' + XzDosyasi + ' .')) <> 0 then
    begin
      Memo4.Lines.Add('Hata: XZ paketleme başarısız!'); Application.ProcessMessages; // Arayüzü tazele!
      Exit(False);
    end;

    // 5. Final: Geçici dosyaları temizle ve zst'yi sil (opsiyonel)
    fpSystem(PChar('rm -rf ' + GeciciKlasor));
     fpSystem(PChar('rm -f ' + ZstDosyasi)); // İstersen orijinal zst'yi silebilirsin

    Memo4.Lines.Add('Başarılı: data.tar.xz oluşturuldu.');Application.ProcessMessages; // Arayüzü tazele!
    Result := True;
  except
    on E: Exception do
    begin
      Memo4.Lines.Add('Dönüştürme sırasında beklenmedik hata: ' + E.Message);
      Application.ProcessMessages;
    end;
  end;
end;

function TForm1.RunCommandAndGetOutput(Command: string): string;
var
  S: string;
begin
  Result := '';
  // Komutu çalıştır ve sonucunu geçici bir dosyaya at, sonra oku
  if RunCommand('/bin/sh', ['-c', Command], S) then
    Result := S;
end;

function TForm1.ReadFileToString(FilePath: string): string;
var
  SL: TStringList;
begin
  Result := '';
  if FileExists(FilePath) then
  begin
    SL := TStringList.Create;
    try
      SL.LoadFromFile(FilePath);
      Result := SL.Text;
    finally
      SL.Free;
    end;
  end;
end;

function TForm1.DebianToPisi(DebName: string): string;
begin
  // En sık rastlanan farklar için bir eşleştirme tablosu
  case LowerCase(DebName) of
    'libc6': result := 'glibc';
    'libx11-6': result := 'libX11';
    'libpng16-16': result := 'libpng';
    'libjpeg62-turbo': result := 'jpeg-turbo';
    'libfontconfig1': result := 'fontconfig';
    'libxext6': result := 'libXext';
    'libxft2': result := 'libXft';
    'libxmu6': result := 'libXmu';
    'libxt6': result := 'libXt';
    else result := DebName; // Eğer listede yoksa olduğu gibi bırak
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  if BaseUnix.fpgetuid <> 0 then
  begin
       if FileExists('/usr/bin/pkexec') then
       K := fpSystem('pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY ' + Application.ExeName)
       else if FileExists('/usr/bin/kdesu') then
       K := fpSystem('kdesu ' + Application.ExeName)
       else
       ShowMessage('Hata: Yetki yönetici (pkexec veya kdesu) bulunamadı! Lütfen uygulamayı terminalden "sudo" ile çalıştırın.');
       halt; // Yetkisiz oturumu kapat
  end;

end;

procedure TForm1.Memo3Change(Sender: TObject);
begin
  Memo3.Lines.SaveToFile('/root/pisilik/pspec.xml');
end;

procedure TForm1.Memo5Change(Sender: TObject);
begin
  Memo5.Lines.SaveToFile('/root/pisilik/actions.py');
end;

procedure TForm1.MemoBetiklerChange(Sender: TObject);
begin
  MemoBetikler.Lines.SaveToFile('/root/pisilik/package.py');
end;

procedure TForm1.PageControl1Change(Sender: TObject);
begin

end;

procedure TForm1.Button1Click(Sender: TObject);
var
  i: Integer;
  HamListe, TemizListe, Paket, Cikti, Komut: string;
  Parcalar: TStringArray;
begin
  if OpenDialog1.Execute then
  begin
    DebDosyasi := OpenDialog1.FileName;
    Memo4.Clear; // Log ekranını temizle
    Memo4.Lines.Add('Seçilen Paket: ' + ExtractFileName(DebDosyasi));
    Application.ProcessMessages;
    // --- 1. ÇALIŞMA DİZİNİNİ HAZIRLA ---
    fpSystem('rm -rf /root/pisilik');
    fpSystem('mkdir -p /root/pisilik');

    Komut := 'cp ' + QuotedStr(DebDosyasi) + ' /root/pisilik/paket.deb';
    fpSystem(PChar(Komut));

    // --- 2. PAKETİ PARÇALA ---
    Memo4.Lines.Add('Paket parçalanıyor (ar x)...'); Application.ProcessMessages; // Arayüzü tazele!
    fpSystem('cd /root/pisilik && ar x paket.deb');

    // --- 3. CONTROL VE CONFFILES DOSYALARINI AYIKLA VE OKU ---
    if FileExists('/root/pisilik/control.tar.zst') then
      fpSystem('tar --zstd -xf /root/pisilik/control.tar.zst -C /root/pisilik/ ./control ./conffiles 2>/dev/null')
    else if FileExists('/root/pisilik/control.tar.xz') then
      fpSystem('tar -xf /root/pisilik/control.tar.xz -C /root/pisilik/ ./control ./conffiles 2>/dev/null')
    else if FileExists('/root/pisilik/control.tar.gz') then
      fpSystem('tar -xf /root/pisilik/control.tar.gz -C /root/pisilik/ ./control ./conffiles 2>/dev/null');

    // Hata ayıklama için log düşelim
    if FileExists('/root/pisilik/conffiles') then
       begin
       Memo4.Lines.Add('Yapılandırma listesi (conffiles) bulundu.');
       Application.ProcessMessages; // Arayüzü tazele!
       end
    else
       Memo4.Lines.Add('Paket yapılandırma dosyası içermiyor (conffiles yok).');
       Application.ProcessMessages; // Arayüzü tazele!

    if FileExists('/root/pisilik/control') then
    begin
       if RunCommand('bash', ['-c', 'grep "^Depends:" /root/pisilik/control | cut -d":" -f2'], Cikti) then
       begin
         HamListe := Trim(Cikti);
         Edit1.Text := HamListe;

         TemizListe := '';
         Parcalar := HamListe.Split([',', '|']);

         for i := 0 to High(Parcalar) do
         begin
           Paket := Trim(Parcalar[i]);
           if Pos(' ', Paket) > 0 then Paket := Copy(Paket, 1, Pos(' ', Paket) - 1);
           if Pos('(', Paket) > 0 then Paket := Copy(Paket, 1, Pos('(', Paket) - 1);

           Paket := Trim(Paket);
           if Paket <> '' then
             TemizListe := TemizListe + Paket + ' ';
         end;

         Edit2.Text := Trim(TemizListe);
         Memo4.Lines.Add('Bağımlılıklar Başarıyla Okundu: ' + Edit2.Text);
         Application.ProcessMessages; // Arayüzü tazele!
       end;
    end
    else
      Memo4.Lines.Add('Uyarı: Bağımlılık listesi (control) okunamadı.');
      Application.ProcessMessages; // Arayüzü tazele!

    // --- 4. ZST -> XZ DÖNÜŞTÜRME FONKSİYONUNU ÇAĞIR ---
    if ZstToXzDonustur('/root/pisilik') then
    begin
      Memo4.Lines.Add('Dönüştürme başarılı veya zaten xz formatında.'); Application.ProcessMessages; // Arayüzü tazele!
      Memo4.Lines.Add('Artık (pspec oluştur) düğmesine basabilirsin.'); Application.ProcessMessages; // Arayüzü tazele!
    end
    else
    begin
      Memo4.Lines.Add('Hata: Data dosyası dönüştürülemedi! İnşa süreci riskli.');Application.ProcessMessages; // Arayüzü tazele!
    end;
  end;
end;

procedure TForm1.Button2Click(Sender: TObject); // Dönüştür.
begin
   Memo2.Lines.Clear;
   if trim(edit2.text)='' then exit;
   Liste := TStringList.Create;
  try
    // Boşluklara göre parçalayıp listeye doldurur
    Liste.Delimiter := ' ';
    Liste.DelimitedText := Edit2.Text;

    SonucXML := '<Runtime>' + sLineBreak;

    for i := 0 to Liste.Count - 1 do
    begin
      if Trim(Liste[i]) <> '' then
      begin
        // Daha önce yazdığımız DebianToPisi fonksiyonunu çağırıyoruz
        PisiPaket := DebianToPisi(Trim(Liste[i]));

        SonucXML := SonucXML + '    <Dependency>' + PisiPaket + '</Dependency>' + sLineBreak;
      end;
    end;

    SonucXML := SonucXML + '</Runtime>';
    Memo2.Lines.Text := SonucXML;

  finally
    Liste.Free;
  end;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  SHA1Sonuc: string;
  PaketAdiTemiz: string;
  ArsivDosyasi, ArsivTipi, Komut: string;
  FullXML, ConfList: TStringList;
  PaketVersiyon: string;
  i: Integer; // Eksik olan değişken eklendi
begin
  // --- 1. ADIM: DOSYA TESPİTİ ---
  ArsivDosyasi := 'data.tar.xz';
  ArsivTipi := 'tarxz';

  if not FileExists('/root/pisilik/' + ArsivDosyasi) then
  begin
    Memo4.Lines.Add('Hata: data.tar.xz bulunamadı!');
    Application.ProcessMessages;
    Exit;
  end;

  // --- 2. ADIM: SHA1 HESAPLAMA ---
   Komut := 'sha1sum "/root/pisilik/' + ArsivDosyasi + '" | awk ''{print $1}''';
  if not RunCommand('bash', ['-c', Komut], SHA1Sonuc) then
  begin
    Memo4.Lines.Add('Hata: SHA1 hesaplanamadı!');
    Exit;
  end;

  SHA1Sonuc := Trim(SHA1Sonuc);

  // --- VERSİYON BİLGİSİNİ OKU VE TEMİZLE ---
    if FileExists('/root/pisilik/control') then
    begin
      if RunCommand('bash', ['-c', 'grep "^Version:" /root/pisilik/control | cut -d":" -f2'], PaketVersiyon) then
      begin
         PaketVersiyon := Trim(PaketVersiyon);

         // 1. Adım: Varsa Epoch (1:) kısmını at
         if Pos(':', PaketVersiyon) > 0 then
           PaketVersiyon := Copy(PaketVersiyon, Pos(':', PaketVersiyon) + 1, Length(PaketVersiyon));

         // 2. Adım: Tire (-) ve Artı (+) işaretlerinden sonrasını tamamen at
         if Pos('-', PaketVersiyon) > 0 then
           PaketVersiyon := Copy(PaketVersiyon, 1, Pos('-', PaketVersiyon) - 1);
         if Pos('+', PaketVersiyon) > 0 then
           PaketVersiyon := Copy(PaketVersiyon, 1, Pos('+', PaketVersiyon) - 1);
         if Pos('~', PaketVersiyon) > 0 then
           PaketVersiyon := Copy(PaketVersiyon, 1, Pos('~', PaketVersiyon) - 1);

         PaketVersiyon := Trim(PaketVersiyon);
      end;
    end;

    // Eğer hala boşsa veya garip karakter kaldıysa güvenli liman:
    if PaketVersiyon = '' then PaketVersiyon := '1.0.0';

  // --- 3. ADIM: PAKET ADI TEMİZLEME ---
  PaketAdiTemiz := LowerCase(StringReplace(ExtractFileName(DebDosyasi), '_', '-', [rfReplaceAll]));
  if Pos('-', PaketAdiTemiz) > 0 then
    PaketAdiTemiz := Copy(PaketAdiTemiz, 1, Pos('-', PaketAdiTemiz) - 1)
  else
    PaketAdiTemiz := ChangeFileExt(PaketAdiTemiz, '');

  // --- 4. ADIM: PSPEC.XML OLUŞTURMA ---
  FullXML := TStringList.Create;
  try
    FullXML.Add('<?xml version="1.0" encoding="utf-8" ?>');
    FullXML.Add('<!DOCTYPE PISI SYSTEM "http://www.pisilinux.org/projeler/pisi/pisi-spec.dtd">');
    FullXML.Add('<PISI>');
    FullXML.Add('    <Source>');
    FullXML.Add('        <Name>' + PaketAdiTemiz + '</Name>');
    FullXML.Add('        <Homepage>https://www.pisilinux.org</Homepage>');
    FullXML.Add('        <Packager><Name>Mecazi</Name><Email>mecazi@pisilinux.org</Email></Packager>');
    FullXML.Add('        <License>GPLv2</License>');
    FullXML.Add('        <Summary xml:lang="tr">' + PaketAdiTemiz + ' paketi</Summary>');
    FullXML.Add('        <Description xml:lang="tr">Deb2Pisi ile otomatik dönüştürülmüştür.</Description>');
    FullXML.Add('        <Archive sha1sum="' + SHA1Sonuc + '" type="' + ArsivTipi + '">file:///root/pisilik/' + ArsivDosyasi + '</Archive>');
    FullXML.Add('    </Source>');

    FullXML.Add('    <Package>');
    FullXML.Add('        <Name>' + PaketAdiTemiz + '</Name>');
    FullXML.Add('        <Summary xml:lang="tr">' + PaketAdiTemiz + ' paketi</Summary>');
    FullXML.Add('        <Description xml:lang="tr">Otomatik dönüştürülmüştür.</Description>');

    if Trim(Edit2.Text) <> '' then
    begin
       FullXML.Add('        <Runtime>');
       FullXML.Add(Memo2.Lines.Text);
       FullXML.Add('        </Runtime>');
    end;

    FullXML.Add('        <Files>');
    // Conffiles Okuma
    if FileExists('/root/pisilik/conffiles') then
    begin
      ConfList := TStringList.Create;
      try
        ConfList.LoadFromFile('/root/pisilik/conffiles');
        for i := 0 to ConfList.Count - 1 do
        begin
          if Trim(ConfList[i]) <> '' then
            FullXML.Add('            <Path fileType="config">' + Trim(ConfList[i]) + '</Path>');
        end;
      finally
        ConfList.Free;
      end;
    end;

    FullXML.Add('            <Path fileType="executable">/usr</Path>');
    FullXML.Add('            <Path fileType="executable">/bin</Path>');
    FullXML.Add('            <Path fileType="library">/lib</Path>');
    FullXML.Add('            <Path fileType="library">/usr/lib</Path>');
    FullXML.Add('            <Path fileType="data">/usr/share</Path>');
    FullXML.Add('        </Files>');
    FullXML.Add('    </Package>');

    FullXML.Add('    <History><Update release="1">');
    FullXML.Add('        <Date>' + FormatDateTime('yyyy-mm-dd', Now) + '</Date>');
    FullXML.Add('        <Version>' + PaketVersiyon + '</Version>');
    FullXML.Add('        <Comment>Paket çevrimi yapıldı.</Comment>');
    FullXML.Add('        <Name>Mecazi</Name><Email>m@m.org</Email>');
    FullXML.Add('    </Update></History>');
    FullXML.Add('</PISI>');

    FullXML.SaveToFile('/root/pisilik/pspec.xml');
    Memo3.Lines.Text := FullXML.Text;
    Memo4.Lines.Add('pspec.xml başarıyla oluşturuldu. Versiyon: ' + PaketVersiyon);
    Application.ProcessMessages;

  finally
    FullXML.Free;
  end;
end;

procedure TForm1.Button4Click(Sender: TObject);
var
  AProcess: TProcess;
  Buffer: array[1..2048] of Byte;
  ReadCount: LongInt;
  StrOutput,S: string;
begin
  // Klasör kontrolü
  if not DirectoryExists('/root/pisilik/') then
  begin
    Memo4.Lines.Add('Çalışma dizini bulunamadı!'); Application.ProcessMessages; // Arayüzü tazele!
    Exit;
  end;

  AProcess := TProcess.Create(nil);
  try
    // Bash üzerinden komutu çalıştırıyoruz
    AProcess.Executable := '/bin/bash';
    AProcess.Parameters.Add('-c');
    AProcess.Parameters.Add('cd /root/pisilik/ && pisi build pspec.xml --no-color');

    // Pipe ayarları
    AProcess.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
    AProcess.Execute;

    // Süreç çalıştığı sürece ÇIKTIYI OKU
    while AProcess.Running or (AProcess.Output.NumBytesAvailable > 0) do
    begin
      if AProcess.Output.NumBytesAvailable > 0 then
      begin
        // Buffer taşmasını önlemek için uygun boyutta oku
        ReadCount := AProcess.Output.Read(Buffer, SizeOf(Buffer));
        if ReadCount > 0 then
        begin
          SetLength(StrOutput, ReadCount);
          Move(Buffer, StrOutput[1], ReadCount);
          // Memo'nun sonuna ekle ve kaydır
          Memo4.Lines.BeginUpdate;
          Memo4.SelStart := Length(Memo4.Text);
          Memo4.SelText := StrOutput;
          Memo4.Lines.EndUpdate;
        end;
      end;
      Application.ProcessMessages; // Arayüzün donmasını engeller
      Sleep(10); // İşlemciyi yormamak için kısa bekleme
    end;

  finally
    AProcess.Free; // Belleği temizle
  end;
  Memo4.Lines.Add('İşlem tamamlandı.');

  if RunCommand('bash', ['-c', 'ls -t /root/pisilik/*.pisi | head -n 1'], S) then
  begin
    S := Trim(S);
    if S <> '' then
    begin
      Memo4.Lines.Add('Tebrikler! Paket oluştu: ' + S);
      Application.ProcessMessages;
    end
    else
      Memo4.Lines.Add('Hata: Paket dosyası bulunamadı. Lütfen hata çıktılarını kontrol edin.');
      Application.ProcessMessages; // Arayüzü tazele!
  end;
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  ActionsFile := TStringList.Create;
  try
    ActionsFile.Add('#!/usr/bin/python');
    ActionsFile.Add('# -*- coding: utf-8 -*-');
    ActionsFile.Add('from pisi.actionsapi import pisitools');
    ActionsFile.Add('from pisi.actionsapi import get');
    ActionsFile.Add('from pisi.actionsapi import shelltools');
    ActionsFile.Add('import os');

    ActionsFile.Add('def install():');
    ActionsFile.Add('    xz_path = "/root/pisilik/data.tar.xz"');

    ActionsFile.Add('    if os.path.exists(xz_path):');
    // shelltools.system komutu os.system'in Pisi versiyonudur
    ActionsFile.Add('        shelltools.system("cp %s ." % xz_path)');
    ActionsFile.Add('        shelltools.system("tar -xf data.tar.xz --no-same-owner --no-same-permissions")');
    ActionsFile.Add('    else:');
    ActionsFile.Add('        print("Hata: data.tar.xz bulunamadi!")');

    ActionsFile.Add('    # Ayiklanan klasorleri sisteme yerlestir');
    ActionsFile.Add('    for folder in ["usr", "etc", "opt", "bin", "lib"]:');
    ActionsFile.Add('        if os.path.exists(folder):');
    ActionsFile.Add('            if os.listdir(folder):');
    ActionsFile.Add('                pisitools.insinto("/", folder)');

    ActionsFile.SaveToFile('/root/pisilik/actions.py');
    Memo5.Lines.Text := ActionsFile.Text;
  finally
    ActionsFile.Free;
  end;
  Memo4.Lines.Add('actions.py shelltools desteği ile düzeltildi.');
  Application.ProcessMessages; // Arayüzü tazele!
end;

procedure TForm1.Button6Click(Sender: TObject);
begin

  if FileExists('/usr/bin/dolphin') then
    fpSystem('dolphin /root/pisilik &')
  else if FileExists('/usr/bin/nemo') then
    fpSystem('nemo /root/pisilik &')
  else
    fpSystem('xdg-open /root/pisilik &');
end;

procedure TForm1.Button7Click(Sender: TObject);
var
  EnSonPaket: string;
  AProcess: TProcess;
  Buffer: array[0..2047] of Byte; // Sabit 2048 byte dizi
  BytesRead: LongInt;
  S: string;
//const
 // LocalBufSize = 2048;
begin
  Memo4.Lines.Add('Kurulum işlemi başlatılıyor...');

  // 1. En son üretilen .pisi paketini bul
  if RunCommand('bash', ['-c', 'ls -t /root/pisilik/*.pisi | head -n 1'], EnSonPaket) then
  begin
    EnSonPaket := Trim(EnSonPaket);
    if (EnSonPaket = '') then Exit;

    AProcess := TProcess.Create(nil);
    try
      AProcess.Executable := '/usr/bin/pisi';
      AProcess.Parameters.Add('it');
      AProcess.Parameters.Add('--no-color');
      //AProcess.Parameters.Add('--yes-all');
      AProcess.Parameters.Add(EnSonPaket);

      AProcess.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
      AProcess.Execute;

      // OKUMA DÖNGÜSÜ
      while AProcess.Running or (AProcess.Output.NumBytesAvailable > 0) do
      begin
        if AProcess.Output.NumBytesAvailable > 0 then
        begin
          // Buffer burada array[0..2047] olduğu için sorun çıkmaz
          BytesRead := AProcess.Output.Read(Buffer, SizeOf(Buffer));

          if BytesRead > 0 then
          begin
            SetString(S, PChar(@Buffer[0]), BytesRead);
            Memo4.Lines.Add(S);
            Application.ProcessMessages; // Arayüzü tazele!

            // Memo'yu en aşağı kaydır (Otomatik Scroll)
            Memo4.SelStart := Length(Memo4.Text);
          end;
        end;
        Sleep(10); // Parantez hatası burada düzeldi: Sleep(10);
        Application.ProcessMessages;
      end;

      if AProcess.ExitStatus = 0 then
    begin
      // 1. Teknik detayları loga (Memo) ekle
      Memo4.Lines.Add('---------------------------------------');
      Memo4.Lines.Add('DURUM: Kurulum başarıyla tamamlandı.');
      Memo4.Lines.Add('PAKET: ' + EnSonPaket);
      Memo4.Lines.Add('ZAMAN: ' + DateTimeToStr(Now));
      Application.ProcessMessages; // Arayüzü tazele!

      // 2. Kullanıcıya net bir bitiş mesajı göster
      ShowMessage('Tebrikler!' + #13#10 +
                  EnSonPaket + ' paketi sisteme kuruldu.' + #13#10 +
                  'Artık menüden veya terminalden çalıştırabilirsiniz.');
    end
    else
    begin
      Memo4.Lines.Add('HATA: Pisi kurulumu sırasında bir sorun oluştu.');
      Application.ProcessMessages; // Arayüzü tazele!
      ShowMessage('Eyvah! Kurulum başarısız oldu. Lütfen logları kontrol edin.');
    end;

    finally
      AProcess.Free;
    end;
  end;
end;

procedure TForm1.Button8Click(Sender: TObject);
var
  ControlArsivi, Content, DosyaListesi: string;
  PackageTemplate: TStringList;

  // Yardımcı: Betikleri Python formatına çevirir
  procedure AddScriptToTemplate(DebFile, PisiFunc: string);
  begin
    PackageTemplate.Add('def ' + PisiFunc + '():');

    // OTOMATİK ZEKA: Eğer Kurulum Sonrası (postInstall) veya Kaldırma Sonrası (postRemove) ise
    // ve pakette uygulama simgesi/menüsü varsa...
    if ((PisiFunc = 'postInstall') or (PisiFunc = 'postRemove')) and (Pos('.desktop', DosyaListesi) > 0) then
    begin
      PackageTemplate.Add('    # Otomatik Ayar: Menü ve Simge veritabanını yenile (Ekleme/Silme)');
      PackageTemplate.Add('    shelltools.system("update-desktop-database -q")');
      PackageTemplate.Add('    shelltools.system("gtk-update-icon-cache -f -t /usr/share/icons/hicolor")');
    end;

    // Debian'dan gelen orijinal betiği oku ve yorum olarak ekle (bilgi amaçlı)
    if FileExists('/root/pisilik/' + DebFile) then
    begin
      Content := ReadFileToString('/root/pisilik/' + DebFile);
      PackageTemplate.Add('    # DEBIAN ' + UpperCase(DebFile) + ' YEDEĞİ (Sadece Bilgi):');
      PackageTemplate.Add('    # ' + StringReplace(Trim(Content), #10, #10 + '    # ', [rfReplaceAll]));
      Memo4.Lines.Add('[+] ' + DebFile + ' bulundu ve yedeklendi.');
    end
    else
    begin
      // Eğer fonksiyon içi boş kalacaksa (ne otomatik komut var ne de orijinal script) pass ekle
      if not (((PisiFunc = 'postInstall') or (PisiFunc = 'postRemove')) and (Pos('.desktop', DosyaListesi) > 0)) then
        PackageTemplate.Add('    pass');
    end;
    PackageTemplate.Add('');
  end;

begin
  // 1. Önce paketin içindeki dosyaların listesini alalım (Röntgen çekiyoruz)
  // Bu satır "DataTarIcerigi" hatasını çözer:
  DosyaListesi := RunCommandAndGetOutput('tar -tf /root/pisilik/data.tar*');

  MemoBetikler.Lines.Clear;
  Memo4.Lines.Add('Paket zekası çalıştırılıyor...'); Application.ProcessMessages; // Arayüzü tazele!

  // 2. Kontrol arşivini aç
  ControlArsivi := '';
  if FileExists('/root/pisilik/control.tar.gz') then ControlArsivi := 'control.tar.gz'
  else if FileExists('/root/pisilik/control.tar.xz') then ControlArsivi := 'control.tar.xz'
  else if FileExists('/root/pisilik/control.tar.zst') then ControlArsivi := 'control.tar.zst';

  if ControlArsivi <> '' then
  begin
    fpSystem('cd /root/pisilik && tar -xvf ' + ControlArsivi);

    PackageTemplate := TStringList.Create;
    try
      // Python kütüphanelerini ekle
      PackageTemplate.Add('from pisi.actionsapi import shelltools');
      PackageTemplate.Add('from pisi.actionsapi import pisitools');
      PackageTemplate.Add('from pisi.actionsapi import get');
      PackageTemplate.Add('');

      // Tüm betik aşamalarını otomatik doldur
      AddScriptToTemplate('preinst', 'preInstall');
      AddScriptToTemplate('postinst', 'postInstall');
      AddScriptToTemplate('prerm', 'preRemove');
      AddScriptToTemplate('postrm', 'postRemove');

      MemoBetikler.Lines.Text := PackageTemplate.Text;
      // package.py dosyasını oluştur
      MemoBetikler.Lines.SaveToFile('/root/pisilik/package.py');

    finally
      PackageTemplate.Free;
    end;
    Memo4.Lines.Add('package.py dosyası hazırlandı.');
    Application.ProcessMessages; // Arayüzü tazele!
  end;
end;

end.
