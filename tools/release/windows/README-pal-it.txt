Takedawn @VERSION@ per Windows (x64) - il disco europeo

Windows 10 o 11 a 64 bit e un driver grafico con Vulkan (qualsiasi driver
AMD, Intel o NVIDIA attuale). README.txt è questo file in inglese.

I dati del gioco
  Takedawn ha bisogno dei dati del gioco dal tuo disco: un'immagine
  (.iso / .xiso) o una cartella estratta di Burnout 3: Takedown,
  @DISC@. Controlla ogni file e li copia in
  %LOCALAPPDATA%\Takedawn PAL\Game. Da un terminale:

      Takedawn.exe --install <immagine-o-cartella>

Le lingue
  Apri le impostazioni (Back e Start, oppure F1): la prima pagina ha due
  lingue.
  - Lingua del gioco: il testo, le voci e i filmati del gioco. Sono
    proposte solo le lingue del tuo disco; quello europeo ha francese,
    tedesco e italiano. Il gioco parte in italiano finché non ne scegli
    un'altra. Il cambio vale dal riavvio successivo.
  - Lingua dell'interfaccia: il menu delle impostazioni e i messaggi di
    Takedawn: inglese (di default), francese, tedesco o italiano. Cambia
    subito.

Dove stanno le cose
  %LOCALAPPDATA%\Takedawn PAL    dati del gioco, cache degli shader
  %APPDATA%\Takedawn PAL         salvataggi, impostazioni, log
  Un aggiornamento (un pacchetto nuovo sopra questo) lascia stare entrambe
  le cartelle.

Come si aggiorna
  1. Chiudi Takedawn.
  2. Estrai il pacchetto nuovo e copialo sopra il vecchio: il programma e
     le DLL vengono sostituiti; i salvataggi, le impostazioni, i dati del
     gioco e la cache degli shader (le due cartelle sopra) restano.

La prima volta
  Takedawn non ha una firma digitale. Quando lo avvii per la prima volta,
  Windows SmartScreen può dire "Windows ha protetto il PC": scegli
  "Ulteriori informazioni" e poi "Esegui comunque".

Le licenze di tutto quello che c'è dentro sono nella cartella licenses.
