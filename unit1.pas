unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, Unix, BaseUnix, process, FileUtil, StrUtils, LCLIntf;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button10: TButton;
    Button11: TButton;
    Button15: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Button7: TButton;
    Button8: TButton;
    Button9: TButton;
    CheckBox1: TCheckBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
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
    ToggleBox1: TToggleBox;
    procedure Button10Click(Sender: TObject);
    procedure Button11Click(Sender: TObject);
    procedure Button15Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure Button7Click(Sender: TObject);
    procedure Button8Click(Sender: TObject);
    procedure Button9Click(Sender: TObject);
    procedure CheckBox1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Memo3Change(Sender: TObject);
    procedure Memo5Change(Sender: TObject);
    procedure MemoBetiklerChange(Sender: TObject);
  private
    PisiDepo: TStringList; // Tüm pisi paketlerini burada tutacağız.
    function ZstToXzDonustur(const CalismaDizini: string): Boolean;
    function RunCommandAndGetOutput(Command: string): string;
    function DebianToPisi(DebName: string): string;
    function ReadFileToString(FilePath: string): string;
    function KomutVarMi(Komut: string): Boolean;

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
  HedefKlasor, exe: string;
implementation

{$R *.lfm}

{ TForm1 }

function TForm1.KomutVarMi(Komut: string): Boolean;
begin
  // which komutu ile sistemde arama yapıyoruz
  Result := fpSystem('which ' + Komut + ' > /dev/null 2>&1') = 0;
end;

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
    Memo4.Lines.Add('Dönüştürülecek .zst dosyası bulunamadı!');
    Application.ProcessMessages;
    Exit(False);
  end;

  try
    Memo4.Lines.Add('Dönüştürme işlemi başlıyor (zst -> xz)...');

    // 2. Temizlik: Eski kalıntıları temizle ve klasör oluştur
    fpSystem(PChar('rm -rf ' + GeciciKlasor));
    fpSystem(PChar('mkdir -p ' + GeciciKlasor));

    // 3. Ayıklama: .zst içeriğini geçici klasöre aç
    Memo4.Lines.Add('Adım 1: zst içeriği dışarı aktarılıyor...');
    Application.ProcessMessages; // Arayüzü tazele!
    if fpSystem(PChar('tar --zstd -xf ' + ZstDosyasi + ' -C ' + GeciciKlasor)) <> 0 then
    begin
      Memo4.Lines.Add('Hata: zst ayıklanamadı! Sistemde "zstd" kurulu mu?');
      Exit(False);
    end;

    // 4. Yeniden Paketleme: İçeriği XZ (J parametresi) olarak paketle
    Memo4.Lines.Add('Adım 2: xz formatında sıkıştırılıyor (Bu biraz sürebilir)...');
    Application.ProcessMessages; // Arayüzü tazele!
    // Not: 'cd' komutuyla klasöre girip paketlemek, dosya yollarının doğru olması için kritiktir.
    if fpSystem(PChar('cd ' + GeciciKlasor + ' && tar -cJf ' + XzDosyasi + ' .')) <> 0 then
    begin
      Memo4.Lines.Add('Hata: XZ paketleme başarısız!');
      Application.ProcessMessages; // Arayüzü tazele!
      Exit(False);
    end;

    // 5. Final: Geçici dosyaları temizle ve zst'yi sil (opsiyonel)
    fpSystem(PChar('rm -rf ' + GeciciKlasor));
     fpSystem(PChar('rm -f ' + ZstDosyasi)); // İstersen orijinal zst'yi silebilirsin

    Memo4.Lines.Add('Başarılı: data.tar.xz oluşturuldu.');
    Application.ProcessMessages; // Arayüzü tazele!
    Result := True;
    except
    on E: Exception do
    begin
      Memo4.Lines.Add('zst Dönüştürme sırasında beklenmedik hata: ' + E.Message);
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
var
  TemizAd, TahminAd: string;
  P: Integer;
begin
  // --- 1. ADIM: PARANTEZ VE VERSİYON TEMİZLİĞİ ---
  TemizAd := Trim(DebName);
  P := Pos('(', TemizAd);
  if P > 0 then
    TemizAd := Trim(Copy(TemizAd, 1, P - 1));

  TemizAd := LowerCase(TemizAd);

  // --- 2. ADIM: MANUEL EŞLEŞTİRME (Sözlük) ---
  case TemizAd of
    // Sistem ve Temel Kütüphaneler
    'libc6':             Exit('glibc');
    'libgcc-s1':         Exit('libgcc');
    'libstdc++6':        Exit('libstdc++');
    'zlib1g':            Exit('zlib');
    'zlib1g-dev':        Exit('zlib-devel');
    'libbz2-1.0':        Exit('bzip2-libs');
    'liblzma5':          Exit('xz-libs');
    'libzstd1':          Exit('zstd');

    // Grafik ve Font (Büyük-Küçük Harf Hassasiyeti Önemli)
    'libx11-6':          Exit('libX11');
    'libxext6':          Exit('libXext');
    'libxft2':           Exit('libXft');
    'libxmu6':           Exit('libXmu');
    'libxt6':            Exit('libXt');
    'libpng16-16':       Exit('libpng');
    'libjpeg62-turbo':   Exit('jpeg-turbo');
    'libfontconfig1':    Exit('fontconfig');
    'libgl1-mesa-glx':   Exit('mesa');

    // Network ve Güvenlik
    'libssl3', 'libssl1.1', 'libssl1.0.0': Exit('openssl');
    'libcurl4':          Exit('curl');
    'libdbus-1-3':       Exit('dbus-libs');
    'libssh2-1':         Exit('libssh2');
    'libpcap0.8':        Exit('libpcap');
    'libpcre3':          Exit('pcre');
    'liblinear4':        Exit('liblinear');
    'libsqlite3-0':      Exit('sqlite');
    'libsqlite3-dev':    Exit('sqlite-devel');

    // Ses ve Diller
    'libasound2':        Exit('alsa-lib');
    'libasound2-dev':    Exit('alsa-lib-devel');
    'libpulse0':         Exit('pulseaudio-libs');
    'python3-tk':        Exit('python3-tk');
    'liblua5.3-0',
    'liblua5.4-0':       Exit('lua');
    'lua-lpeg':          Exit('lua-lpeg');
    'nmap-common':       Exit('nmap');
  end;

  // --- 3. ADIM: OTOMATİK KURALLAR (-dev -> -devel) ---
  TahminAd := TemizAd;
  if EndsText('-dev', TahminAd) then
    TahminAd := Copy(TahminAd, 1, Length(TahminAd) - 4) + '-devel';

  // --- 4. ADIM: PİSİ DEPOSUNDA DOĞRULAMA ---
  // Eğer tahmin ettiğimiz isim (zstd-devel gibi) pisi_liste.txt içinde varsa onu kullan
  if (PisiDepo <> nil) and (PisiDepo.IndexOf(TahminAd) <> -1) then
    Result := TahminAd
  else
    Result := TemizAd; // Manuel eşleşme yoksa ve depoda bulunamazsa temiz adı döndür
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  EksikPaketler: string;
begin

  //---ROOT OL---
  if BaseUnix.fpgetuid <> 0 then
    begin
      if FileExists('/usr/bin/pkexec') then
        K := fpSystem('pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY ' + Application.ExeName)
      else if FileExists('/usr/bin/kdesu') then
        K := fpSystem('kdesu ' + Application.ExeName)
      else
      begin
        ShowMessage('Hata: Yönetici yetkisi alınamadı! Lütfen sudo ile çalıştırın.');
        K := -1;
      end;
      halt;
    end;
  // ----------------------------------------------------------------------------------


  //---KÜTÜPHANE DESTEĞİ VERİLMİŞ Mİ---
  if FileExists('/usr/lib/libtinfo.so.6') then
  begin
       CheckBox1.OnChange := nil;
       CheckBox1.Checked:=true;
       CheckBox1.OnChange := @CheckBox1Change;
  end;
  // ----------------------------------------------------------------------------------


  //---PAKET İSİMLERİNİ İNDİR---
  PisiDepo := TStringList.Create;
  PisiDepo.Sorted := True; // Arama hızı için sıralı olması şart
  if FileExists('pisi_liste.txt') then
  PisiDepo.LoadFromFile('pisi_liste.txt');
  // ----------------------------------------------------------------------------------

  // --- KRİTİK BAĞIMLILIK KONTROLÜ ---
  EksikPaketler := '';
  if not KomutVarMi('ar') then EksikPaketler := EksikPaketler + ' - binutils (ar)' + sLineBreak;
  if not KomutVarMi('sha1sum') then EksikPaketler := EksikPaketler + ' - coreutils (sha1sum)' + sLineBreak;
  if not KomutVarMi('pisi') then EksikPaketler := EksikPaketler + ' - pisi' + sLineBreak;
  if not KomutVarMi('tar') then EksikPaketler := EksikPaketler + ' - tar' + sLineBreak;
  if not KomutVarMi('xz') then EksikPaketler := EksikPaketler + ' - xz' + sLineBreak;

  if EksikPaketler <> '' then // Eksik bağımlılık varsa
  begin
    ShowMessage('Dikkat! Programın çalışması için gerekli bazı paketler eksik:'+sLineBreak+
    EksikPaketler + sLineBreak +'Lütfen bu paketleri Pisi depolarından kurun.');
    Memo4.Lines.Add('[!] SİSTEM UYARISI: Eksik bağımlılıklar tespit edildi!');
  end
  else
  begin
    Memo4.Lines.Add('[+] Sistem kontrolü başarılı: Tüm bağımlılıklar kurulu.');
  end;
  // ----------------------------------------------------------------------------------

  Memo4.Lines.Add('Deb2Pisi Başlatıldı.');
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


procedure TForm1.Button1Click(Sender: TObject);
var
  i: Integer;
  HamListe, TemizListe, Paket, Cikti, Komut: string;
  Parcalar: TStringArray;
begin
  if OpenDialog1.Execute then
  begin
    DebDosyasi := OpenDialog1.FileName;
    Label4.Caption:=ExtractFileName(DebDosyasi);
    Label4.Caption:=copy(Label4.Caption,0,(pos('_',Label4.Caption)-1)); // Seçilen deb paketini ilan et

     // --- 1. TEMİZLİK YAP ---
    Memo4.Clear; // Log ekranını temizle
    Edit1.Clear;
    Edit2.Clear;
    Edit3.Clear;
    Memo2.Lines.Clear;
    Memo3.Lines.Clear;
    Memo5.Lines.Clear;
    MemoBetikler.Lines.Clear;
    fpSystem('mkdir -p /root/pisilik');
    fpSystem('rm -rf /root/pisilik/*');
    Memo4.Lines.Add('Seçilen Paket: ' + ExtractFileName(DebDosyasi));
    Application.ProcessMessages;
    //---------------------------------------------------------------------------


    // --- 2. PAKETİ PARÇALA ---
    Komut := 'cp ' + QuotedStr(DebDosyasi) + ' /root/pisilik/paket.deb';
    fpSystem(PChar(Komut));
    Memo4.Lines.Add('Paket parçalanıyor (ar x)...');
    Application.ProcessMessages; // Arayüzü tazele!
    fpSystem('cd /root/pisilik && ar x paket.deb');
    //------------------------------------------------------------------------------



    // --- 3. CONTROL VE DATA DOSYALARINI AYIKLA VE OKU ---
    if FileExists('/root/pisilik/control.tar.zst') then
    fpSystem('tar --zstd -xf /root/pisilik/control.tar.zst -C /root/pisilik/')
    else if FileExists('/root/pisilik/control.tar.xz') then
    fpSystem('tar -xf /root/pisilik/control.tar.xz -C /root/pisilik/')
    else if FileExists('/root/pisilik/control.tar.gz') then
    fpSystem('tar -xf /root/pisilik/control.tar.gz -C /root/pisilik/');

    if FileExists('/root/pisilik/data.tar.zst') then
    fpSystem('tar --zstd -xf /root/pisilik/data.tar.zst -C /root/pisilik/')
    else if FileExists('/root/pisilik/data.tar.xz') then
    fpSystem('tar -xf /root/pisilik/data.tar.xz -C /root/pisilik/')
    else if FileExists('/root/pisilik/data.tar.gz') then
    fpSystem('tar -xf /root/pisilik/data.tar.gz -C /root/pisilik/');
    //------------------------------------------------------------------------------


    //---ÇALIŞTIRMA KOMUTU AYARLA---
    if DirectoryExists('/root/pisilik/data/usr/bin/') then
    begin
    if RunCommand('bash', ['-c', 'ls /root/pisilik/data/usr/bin/'], exe) then begin end;
    end;
    if DirectoryExists('/root/pisilik/usr/bin/') then
    begin
    if RunCommand('bash', ['-c', 'ls /root/pisilik/usr/bin/'], exe) then begin end;
    end;
    if DirectoryExists('/root/pisilik/usr/games/') then
    begin
    if RunCommand('bash', ['-c', 'ls /root/pisilik/usr/games/'], exe) then begin exe:='/usr/games/'+exe; end;
    end;
    //------------------------------------------------------------------------------



    //---BAĞIMLILIKLARI AYARLA---
    if FileExists('/root/pisilik/control') then
    begin
      if RunCommand('bash', ['-c', 'grep -E "^(Depends|Pre-Depends):" /root/pisilik/control | cut -d":" -f2- | tr "\n" ","'], Cikti) then
       begin
         HamListe := Trim(Cikti);
         Edit1.Text := HamListe;
         TemizListe := '';
         Parcalar := HamListe.Split([',', '|']);
         // TEMİZLİK
         for i := 0 to High(Parcalar) do
         begin
           // Baştaki ve sondaki boşlukları temizle
           Paket := Trim(Parcalar[i]);
           if Pos('(', Paket) > 0 then
             Paket := Copy(Paket, 1, Pos('(', Paket) - 1);
           Paket := Trim(Paket);
           if Paket <> '' then
           begin
             if TemizListe = '' then
               TemizListe := Paket
             else
               TemizListe := TemizListe + ' ' + Paket;
           end;
         end;

         Edit2.Text := Trim(TemizListe);
         Button9Click(self); //pisi bağımlılıklarına dönüştür.
         Memo4.Lines.Add('Bağımlılık araştırması bitti: ' + Edit2.Text);
         Application.ProcessMessages; // Arayüzü tazele!
       end;
       end
       else
       Memo4.Lines.Add('Uyarı: Bağımlılık bulunamadı.');
       Application.ProcessMessages; // Arayüzü tazele!
       //------------------------------------------------------------------------------




    // --- 4. ZST -> XZ DÖNÜŞTÜRME FONKSİYONUNU ÇAĞIR ---
    if not FileExists('/root/pisilik/control.tar.zst') then exit; // ZST UZANTILI DOSYA YOKSA ÇIK
    if ZstToXzDonustur('/root/pisilik') then
    begin
      Memo4.Lines.Add('zst ==> xz  dönüştürme başarılı.'); Application.ProcessMessages; // Arayüzü tazele!
      Memo4.Lines.Add('Artık (pspec oluştur) düğmesine basabilirsin.'); Application.ProcessMessages; // Arayüzü tazele!
    end
    else
    begin
      Memo4.Lines.Add('zst uzantılı data dosyası dönüştürülemedi! İnşa süreci riskli.');Application.ProcessMessages; // Arayüzü tazele!
    end;
    end;
    //------------------------------------------------------------------------------
end;


procedure TForm1.Button10Click(Sender: TObject);
begin
  fpSystem('rm -rf /root/pisilik/*');
  Memo4.Lines.Clear;
  Memo4.Lines.Add('Geçici dosyalar temizlendi. Saha yeni paket için hazır!');
end;

procedure TForm1.Button11Click(Sender: TObject); // PAKETİ KALDIR
var
  EnSonPaket: string;
  AProcess: TProcess;
  Buffer: array[0..2047] of Byte; // Sabit 2048 byte dizi
  BytesRead: LongInt;
  S: string;
begin
  Memo4.Lines.Add('..................................');
  Memo4.Lines.Add('...KALDIRMA İŞLEMİ BAŞLATILIYOR...');

  // 1. En son üretilen .pisi paketini bul
  if RunCommand('bash', ['-c', 'ls -t /root/pisilik/*.pisi | head -n 1'], EnSonPaket) then
  begin
    EnSonPaket := Trim(EnSonPaket);
    EnSonPaket := copy(EnSonPaket,0,(pos('-',EnSonPaket)-1));
    EnSonPaket := ExtractFileName(EnSonPaket);
    if (EnSonPaket = '') then Exit;

    AProcess := TProcess.Create(nil);
    try
      AProcess.Executable := '/usr/bin/pisi';
      AProcess.Parameters.Add('rm');
      AProcess.Parameters.Add('--no-color');
      AProcess.Parameters.Add(EnSonPaket);

      AProcess.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
      AProcess.Execute;

      // OKUMA DÖNGÜSÜ
      while AProcess.Running or (AProcess.Output.NumBytesAvailable > 0) do
      begin
        if AProcess.Output.NumBytesAvailable > 0 then
        begin
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
        Sleep(10); // Parantez hatası burada düzeldi:
        Application.ProcessMessages;
      end;

      if AProcess.ExitStatus = 0 then
    begin
      // 1. Teknik detayları loga (Memo) ekle
      Memo4.Lines.Add('---------------------------------------');
      Memo4.Lines.Add('DURUM: Paket kaldırıldı.');
      Memo4.Lines.Add('PAKET: ' + EnSonPaket);
      Memo4.Lines.Add('ZAMAN: ' + DateTimeToStr(Now));
      Application.ProcessMessages; // Arayüzü tazele!
    end
    else
    begin
      Memo4.Lines.Add('HATA: Paket kaldırma sırasında bir sorun oluştu.');
      Application.ProcessMessages; // Arayüzü tazele!
      ShowMessage('HATA: Paket kaldırma sırasında bir sorun oluştu.');
    end;

    finally
      AProcess.Free;
    end;
  end;
end;






procedure TForm1.Button15Click(Sender: TObject);
var
  AProcess: TProcess;
begin
  if exe = '' then Exit;
  Memo4.Lines.Add('>>> ' + exe + ' başlatılıyor...');
  AProcess := TProcess.Create(nil);
  try
    //AProcess.Executable := '/usr/bin/konsole';
    //AProcess.Parameters.Add('--noclose'); // xterm'deki '-hold' yerine geçer
    AProcess.Executable := '/usr/bin/xterm';
    AProcess.Parameters.Add('-hold'); // Program kapansa bile pencereyi açık tutar (hata görmek için)
    AProcess.Parameters.Add('-e');
    AProcess.Parameters.Add(exe);
    AProcess.Execute;

    Memo4.Lines.Add('✓ Komut gönderildi: ' + exe);
  finally
    AProcess.Free;
  end;
end;



procedure TForm1.Button2Click(Sender: TObject);
var
  S, Kelime, SonucXML: string;
  i: Integer;
begin

  // ARTIK KAYNAĞIMIZ EDIT3 (Pisi Karşılıkları)
  S := Trim(Edit3.Text);

  if S = '' then
  begin
    Exit;
  end;

  // --- 1. RUNTIME (BAĞIMLILIKLAR) KISMI ---
  SonucXML := '    <Runtime>' + sLineBreak;
  Kelime := '';
  S := S + ' '; // Son kelimeyi yakalamak için

  for i := 1 to Length(S) do
  begin
    if S[i] <> ' ' then
      Kelime := Kelime + S[i]
    else
    begin
      if Kelime <> '' then
      begin
        // Mükerrer kontrolü
        if Pos('<Dependency>' + Kelime + '</Dependency>', SonucXML) = 0 then
          SonucXML := SonucXML + '        <Dependency>' + Kelime + '</Dependency>' + sLineBreak;

        Kelime := '';
      end;
    end;
  end;
  SonucXML := SonucXML + '    </Runtime>' + sLineBreak;
  Memo2.Lines.Text := SonucXML;
  // -------------------------------------------------------------
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  SHA1Sonuc, PaketAdiTemiz, ArsivDosyasi, ArsivTipi, Komut, PaketVersiyon: string; //, Satir
  FullXML, MemoSatirlari: TStringList; // ConfList,
 // DosyaAdi: string;
 // i, P: Integer;
 // HedefYol: string; // Hepsi string (metin) tipinde
begin

  // --- 1. ADIM: DOSYA TESPİTİ ---
  if FileExists('/root/pisilik/data.tar.xz') then
  begin
    ArsivDosyasi := 'data.tar.xz';
    ArsivTipi := 'tarxz';
  end
  // XZ yoksa GZ kontrolü yapalım
  else if FileExists('/root/pisilik/data.tar.gz') then
  begin
    ArsivDosyasi := 'data.tar.gz';
    ArsivTipi := 'targz'; // Pisi pspec.xml içinde 'targz' olarak bekler
  end
  else
  begin
    Memo4.Lines.Add('Hata: Ne data.tar.xz ne de data.tar.gz bulunabildi!');
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

  // --- 3. ADIM: VERSİYON TEMİZLEME ---
  PaketVersiyon := '1.0.0';
  if FileExists('/root/pisilik/control') then
  begin
    if RunCommand('bash', ['-c', 'grep "^Version:" /root/pisilik/control | cut -d":" -f2'], PaketVersiyon) then
    begin
      PaketVersiyon := Trim(PaketVersiyon);
      if Pos(':', PaketVersiyon) > 0 then PaketVersiyon := Copy(PaketVersiyon, Pos(':', PaketVersiyon) + 1, Length(PaketVersiyon));
      if Pos('-', PaketVersiyon) > 0 then PaketVersiyon := Copy(PaketVersiyon, 1, Pos('-', PaketVersiyon) - 1);
      if Pos('+', PaketVersiyon) > 0 then PaketVersiyon := Copy(PaketVersiyon, 1, Pos('+', PaketVersiyon) - 1);
      if Pos('~', PaketVersiyon) > 0 then PaketVersiyon := Copy(PaketVersiyon, 1, Pos('~', PaketVersiyon) - 1);
      PaketVersiyon := Trim(PaketVersiyon);
    end;
  end;

  // --- 4. ADIM: PAKET ADI ---
  PaketAdiTemiz := LowerCase(StringReplace(ExtractFileName(DebDosyasi), '_', '-', [rfReplaceAll]));
  if Pos('-', PaketAdiTemiz) > 0 then
    PaketAdiTemiz := Copy(PaketAdiTemiz, 1, Pos('-', PaketAdiTemiz) - 1)
  else
    PaketAdiTemiz := ChangeFileExt(PaketAdiTemiz, '');
  PaketAdiTemiz := Label4.Caption;

  // --- 5. ADIM: PSPEC.XML OLUŞTURMA ---
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

    // --- 6. ADIM: MEMO2 yi ekle ---
    if Trim(Memo2.Lines.Text) <> '' then
    begin
      MemoSatirlari := TStringList.Create;
      MemoSatirlari.Text := Memo2.Lines.Text;
      FullXML.Add(MemoSatirlari.Text);
      MemoSatirlari.Free;
    end;

    FullXML.Add('    <Files>');
    FullXML.Add('        <Path fileType="all">/</Path>');
    FullXML.Add('    </Files>');

    FullXML.Add('    </Package>');

    // --- 8. ADIM: GEÇMİŞ (HISTORY) ---
    FullXML.Add('    <History><Update release="1">');
    FullXML.Add('        <Date>' + FormatDateTime('yyyy-mm-dd', Now) + '</Date>');
    FullXML.Add('        <Version>' + PaketVersiyon + '</Version>');
    FullXML.Add('        <Comment>Paket çevrimi yapıldı.</Comment>');
    FullXML.Add('        <Name>Mecazi</Name><Email>m@m.org</Email>');
    FullXML.Add('    </Update></History>');
    FullXML.Add('</PISI>');

    FullXML.SaveToFile('/root/pisilik/pspec.xml');
    Memo3.Lines.Text := FullXML.Text;
    Memo4.Lines.Add('[+] pspec.xml başarıyla oluşturuldu. Paket Versiyon: ' + PaketVersiyon);
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
    ActionsFile.Add('');
    ActionsFile.Add('from pisi.actionsapi import shelltools');
    ActionsFile.Add('from pisi.actionsapi import pisitools');
    ActionsFile.Add('import os');
    ActionsFile.Add('');
    ActionsFile.Add('# data klasörü varsa WorkDir i değiştir');
    ActionsFile.Add('WorkDir = "data" if shelltools.isDirectory("data") else "."');
    ActionsFile.Add('');
    ActionsFile.Add('def safe_insinto(target, source):');
    ActionsFile.Add('    """Boş dizinleri atlar, boşsa uyarı basar."""');
    ActionsFile.Add('    if shelltools.isDirectory(source):');
    ActionsFile.Add('        if os.listdir(source):');
    ActionsFile.Add('            pisitools.insinto(target, "%s/*" % source)');
    ActionsFile.Add('        else:');
    ActionsFile.Add('            print("Uyarı: ''{0}'' dizini boş, kopyalanmadı.".format(source))');
    ActionsFile.Add('');
    ActionsFile.Add('def install():');
    ActionsFile.Add('    for d in ["usr", "opt", "etc", "lib", "var"]:');
    ActionsFile.Add('        safe_insinto("/%s" % d, d)');

    ActionsFile.SaveToFile('/root/pisilik/actions.py');
    Memo5.Lines.Text := ActionsFile.Text;
  finally
    ActionsFile.Free;
  end;
  Memo4.Lines.Add('>>> actions.py oluşturuldu.');
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
  Memo4.Lines.Add('.................................');
  Memo4.Lines.Add('...KURULUM İŞLEMİ BAŞLATILIYOR...');

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
  Content,DosyaListesi: string; //ControlArsivi,
  PackageTemplate: TStringList; //, ConfList
  //i: Integer;


    ///////////////////
    procedure AddScriptToTemplate(DebFile, PisiFunc: string);
    begin
    PackageTemplate.Add('def ' + PisiFunc + '():');
    if ((PisiFunc = 'postInstall') or (PisiFunc = 'postRemove')) and (Pos('.desktop', DosyaListesi) > 0) then
    begin
      PackageTemplate.Add('    shelltools.system("update-desktop-database -q")');
      PackageTemplate.Add('    shelltools.system("gtk-update-icon-cache -f -t /usr/share/icons/hicolor")');
    end;

    if FileExists('/root/pisilik/' + DebFile) then
    begin  //shelltools.remove("/usr/share/icons/baglama.png")
      Content := ReadFileToString('/root/pisilik/' + DebFile);
      PackageTemplate.Add('    # DEBIAN ' + UpperCase(DebFile) + ' YEDEĞİ:');
      PackageTemplate.Add('    # ' + StringReplace(Trim(Content), #10, #10 + '    # ', [rfReplaceAll]));
      Memo4.Lines.Add('[+] ' + DebFile + ' bulundu ve yedeklendi.');
    end
    else
    begin
      if not (((PisiFunc = 'postInstall') or (PisiFunc = 'postRemove')) and (Pos('.desktop', DosyaListesi) > 0)) then
        PackageTemplate.Add('    pass');
    end;
    PackageTemplate.Add('');
    end;
    ///////////////////


begin
  DosyaListesi := RunCommandAndGetOutput('tar -tf /root/pisilik/data.tar*');
  MemoBetikler.Lines.Clear;
  Memo4.Lines.Add('package.py oluşturuluyor...');

  PackageTemplate := TStringList.Create;
  try
    PackageTemplate.Add('from pisi.actionsapi import shelltools');
    PackageTemplate.Add('from pisi.actionsapi import pisitools');
    PackageTemplate.Add('');
    PackageTemplate.Add('');
    PackageTemplate.Add('    # Bu kısımda elle düzenleme yapabilirsiniz.');
    PackageTemplate.Add('    # Örnek: shelltools.remove("/usr/share/icons/bglm.png")');
    PackageTemplate.Add('');

    AddScriptToTemplate('preinst', 'preInstall');
    AddScriptToTemplate('postinst', 'postInstall');
    AddScriptToTemplate('prerm', 'preRemove');
    AddScriptToTemplate('postrm', 'postRemove');

    MemoBetikler.Lines.Text := PackageTemplate.Text;
    MemoBetikler.Lines.SaveToFile('/root/pisilik/package.py');

  finally
    PackageTemplate.Free;
  end;

  Memo4.Lines.Add('package.py hazırlandı.');
  Application.ProcessMessages;
end;

procedure TForm1.Button9Click(Sender: TObject); // Tercüme Et ve Edit3'e Yaz
var
  S, Kelime, PisiPaket, GuncelEdit3: string;
  i: Integer;
begin
  S := Trim(Edit2.Text);
  if S = '' then
  begin
    Memo4.Lines.Add('Bağımlılık bulunamadı.Bağımlılık yok.');
    Exit;
  end;

  GuncelEdit3 := '';
  Kelime := '';
  S := S + ' '; // Son kelimeyi yakalamak için boşluk ekliyoruz

  for i := 1 to Length(S) do
  begin
    if S[i] <> ' ' then
      Kelime := Kelime + S[i]
    else
    begin
      if Kelime <> '' then
      begin
        // TERCÜME BURADA OLUYOR
        PisiPaket := DebianToPisi(Kelime);

        if GuncelEdit3 <> '' then GuncelEdit3 := GuncelEdit3 + ' ';
        GuncelEdit3 := GuncelEdit3 + PisiPaket;

        Kelime := '';
      end;
    end;
  end;

  // Sonucu Edit3'e basıyoruz
  Edit3.Text := GuncelEdit3;

  // LOG ekranına da bilgi düşelim
  Memo4.Lines.Add('Debian bağımlılıkları Pisi karşılıklarına çevrildi.');
end;

procedure TForm1.CheckBox1Change(Sender: TObject);
begin
  if CheckBox1.Checked then  // Kütüphane desteği ver
  begin
    Memo4.Lines.Add('>>> İşlem başlatılıyor...');

         fpSystem('ln -sf /usr/lib/libncursesw.so.6 /usr/lib/libtinfo.so.6');
         fpSystem('ln -sf /usr/lib/libncursesw.so.6 /usr/lib/libncurses.so.6');
         fpSystem('ln -sf /usr/lib/libpcre.so.1 /usr/lib/libpcre.so.3');
         fpSystem('ln -sf /usr/lib/libpcap.so.1 /usr/lib/libpcap.so.0.8');
         fpSystem('ln -sf /usr/lib/libreadline.so.8 /usr/lib/libreadline.so.7');
         fpSystem('ln -sf /usr/lib/libboost_program_options.so.1.90.0 /usr/lib/libboost_program_options.so.1.74.0');
         fpSystem('ln -sf /usr/lib/libboost_system.so.1.90.0 /usr/lib/libboost_system.so.1.74.0');
         fpSystem('ln -sf /usr/lib/libncursesw.so.6.5 /usr/lib/libtinfo.so.5');
         fpSystem('ln -sf /usr/lib/libjpeg.so.8 /usr/lib/libjpeg.so.62');

         fpSystem('ldconfig');



      // İşlem bittikten sonra dosyayı kontrol et (Stream yerine direkt dosya kontrolü daha güvenli)
      if FileExists('/usr/lib/libtinfo.so.6') then
      begin
        Memo4.Lines.Add('✓ BAŞARILI: Köprü oluşturuldu.');
      end
      else
      begin
        Memo4.Lines.Add('X HATA: Dosya kopyalanamadı.');
      end;
  end
  //------------------------------------------------------------------------------


  else
  begin //---KÜTÜPHANE DESTEĞİNİ KALDIR---
    Memo4.Lines.Add('---');
    Memo4.Lines.Add('>>> Sistem temizliği başlatılıyor (Restorasyon)...');

    fpSystem('rm -fv /usr/lib/libtinfo.so.6');
    fpSystem('rm -fv /usr/lib/libncurses.so.6');
    fpSystem('rm -fv /usr/lib/libpcre.so.3');
    fpSystem('rm -fv /usr/lib/libpcap.so.0.8');
    fpSystem('rm -fv /usr/lib/libreadline.so.7');
    fpSystem('rm -fv /usr/lib/liblua5.3-lpeg.so.2');
    fpSystem('rm -fv /usr/lib/liblua5.3.so.0');
    fpSystem('rm -fv /usr/lib/libboost_program_options.so.1.74.0');
    fpSystem('rm -fv /usr/lib/libboost_system.so.1.74.0');
    fpSystem('rm -fv /usr/lib/libtinfo.so.5');
     fpSystem('rm -fv /usr/lib/libjpeg.so.62');

    fpSystem('ldconfig');


      // Kontrol: Dosyalar gerçekten silindi mi?
      if not FileExists('/usr/lib/libtinfo.so.6') then
      begin
        Memo4.Lines.Add('✓ Temizlik Tamamlandı: Sistem orijinal haline döndü.');
        Memo4.Lines.Add('✓ ldconfig güncellendi.');
      end
      else
      begin
        Memo4.Lines.Add('X HATA: Bazı dosyalar silinemedi!');
      end;

  end;
  //------------------------------------------------------------------------------
end;

end.
