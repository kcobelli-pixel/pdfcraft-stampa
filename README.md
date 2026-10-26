# PdfCraft con le patch

Questo repository ricompila ogni nuova versione di [PdfCraft](https://github.com/storytold/pdfcraft)
con due modifiche e la pubblica tra le [release](../../releases), con lo stesso numero di versione
di quella ufficiale:

- **Correzione della stampa (Windows).** Con alcune stampanti Brother (per esempio MFC-L3760CDW,
  MFC-L2710DN, HL-L3230CDW) PdfCraft non stampa e mostra
  `Render Error: Interfaccia non supportata (0x80040003)`: il driver rifiuta il PrintTicket della
  stampa XPS (un `JobPrintSpeed` doppio, vedi
  [ArcticLampyrid/winprint.rs#3](https://github.com/ArcticLampyrid/winprint.rs/issues/3)). Con la
  correzione proposta in storytold/winprint.rs#6 e storytold/craft-libs#188, PdfCraft stampa lo
  stesso documento tramite GDI (come immagine fino a 300 dpi), passando al driver copie,
  fronte-retro e formato del lavoro. Le altre stampanti stampano come prima.
- **Più firme salvate (Windows e Mac).** Nel pannello Compila e firma si possono tenere più firme
  e più sigle, non una sola. La prima in alto è quella che mette lo strumento Firma; cliccandone
  un'altra, quella sale in cima e la puoi posizionare. "Aggiungi firma" ne aggiunge un'altra senza
  perdere quelle che hai. Le firme restano nelle preferenze di PdfCraft: se apri la versione
  ufficiale (per esempio subito dopo un aggiornamento) vedi solo quella in cima, ma le altre
  restano salvate e ricompaiono quando riapplichi la patch.

Sono build **non ufficiali e non firmate**, fatte da GitHub Actions a partire dal codice pubblico
(`.github/workflows/build.yml`): il controllo avviene ogni ora, quindi una nuova versione di
PdfCraft è pronta circa un'ora dopo l'uscita (il Mac richiede un po' di più).

## Windows

Una volta sola: scarica `PdfCraft-Patch-Windows.zip` dalla release
[strumenti](../../releases/tag/strumenti). Prima di estrarlo, aprilo con il tasto destro
› Proprietà › spunta **Annulla blocco** › OK. Estrai la cartella dove preferisci.

Dopo ogni aggiornamento di PdfCraft fatto con l'ArtCraft Launcher:

1. chiudi PdfCraft;
2. fai doppio clic su `Applica-patch.cmd` (se Windows mostra "PC protetto", scegli
   "Ulteriori informazioni" › "Esegui comunque");
3. quando Windows chiede il permesso di installare, rispondi **Sì** (l'autore risulta
   sconosciuto perché la build non è firmata).

## Mac

Una volta sola: scarica `PdfCraft-Patch-Mac.zip` dalla stessa release e aprilo: compare
`Applica-patch.command`. Mettilo dove preferisci.

Dopo ogni aggiornamento di PdfCraft fatto con l'ArtCraft Launcher:

1. chiudi PdfCraft;
2. fai doppio clic su `Applica-patch.command`: si apre il Terminale e fa tutto da solo.

La prima volta macOS non lo apre perché il file viene da internet: vai in Impostazioni di
Sistema › Privacy e sicurezza, scorri in basso e scegli **Apri comunque**. Se usi un ID digitale
del Portachiavi, PdfCraft può chiederti di nuovo il permesso di usarlo: consenti.

## Come funziona

Lo script legge la versione installata, scarica la build della stessa versione, ne controlla
l'impronta SHA-256 e la installa. Se la build non è ancora pronta, te lo dice e non tocca niente.
Quando la versione ufficiale conterrà già tutto quello che aggiunge la patch, lo script lo dice con
una finestra di avviso e non installa più niente. Per tornare alla versione ufficiale basta
**Reinstalla** nel Launcher.

## Contenuto

- `apply_print_fix.sh`: applica la correzione della stampa alle revisioni esatte di craft-libs e
  winprint che usa una versione di PdfCraft. Riconosce quando le sorgenti ufficiali contengono già
  una correzione.
- `apply_signatures.sh`: applica le firme multiple; riconosce quando PdfCraft le ha già.
- `patches/`: le modifiche (craft-print, winprint, firme multiple e il loro test).
- `windows/`, `mac/`: i file da cliccare.

Le modifiche seguono le licenze dei progetti da cui vengono (PdfCraft e craft-libs: MIT OR
Apache-2.0; winprint: BSD-3-Clause).
