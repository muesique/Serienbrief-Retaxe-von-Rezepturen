# Setze die Dateinamen
set latex_file "rezepturen.tex"
set csv_file "daten.csv"

# Statische Platzhalter als Tcl-Liste
set datum_jetzt [exec date -d today +%d.%m.%Y]


set gkv "AOK Hessen"
set quartal "1. Quartal 2024"
set ikz "301234567"
set kostentraeger "109876543"
set abrechnungszentrum "307894561"
set datum_schreiben "30.09.2024"

# latex-File einlesen
set texfile ""
set f [open $latex_file r]
while {[gets $f zeile] >= 0} {
	append texfile $zeile "\n"
}
close $f

# Variablen, die für alle Dokumente gleich bleiben
# Schlüssel-Wert-Zuordnung
# Wert mit \" ... \" escapen, damit Leerzeichen nicht die Zuordnung zerhauen!
# Escapen nur bei Werten MIT Leerzeichen nötig.
set variablen_gesamtdokument "
	GKV \"AOK Hessen\"
	DATUMJETZT $datum_jetzt
	QUARTAL \"$quartal\"
	IKZ $ikz
	KOSTENTRAEGER $kostentraeger
	ABRECHNUNGSZENTRUM $abrechnungszentrum
	DATUMSCHREIBEN $datum_schreiben
"

# konstanter Teil
# Ersetze die Platzhalter in der neuen Datei
foreach {platzhalter ersetzung} $variablen_gesamtdokument {
	regsub -all "$platzhalter" $texfile "$ersetzung" texfile
	# Ich mag zwar "string map", aber ich habe keine Weg gefunden,
	# aus der Liste in $ersetzung ohne komplette Expansion des Listenelements
	# einzufügen. Damit wird aus jedem Wort des Wertes aus dem Schlüssel-Werte-Paar
	# neue $platzhalter und $ersetzung!
	#set texfile [string map -nocase "$platzhalter $ersetzung" $texfile]
}

# Öffne die CSV-Datei zum Lesen
set csv [open $csv_file r]

# variabler Teil!
# Lese jede Zeile der CSV-Datei
while {[gets $csv line] != -1} {
	# den zu bearbeitenden tex-Sting für jedes Dokument neu setzen
	set texfile_variabel $texfile
	
    # Teile die Zeile in Name, Datum und VSNR auf (anpassen, wenn mehr Spalten vorhanden sind)
    # SO IST DIE REIHENFOLGE IN DER CSV!
    lassign [split $line ";"] name date vsnr picnr rezeptur betrag substanz

    # Erstelle einen neuen Dateinamen
    set new_file [file join [file dirname $latex_file] [file rootname $latex_file]$vsnr.tex]
    # den Dateinamen in einer Liste für die pdf-Erstellung später speichern
	set tex_file_liste [lappend tex_file_liste $new_file]

	# Liste mit den zu ersetzenden Platzhaltern mit den entsprechenden Variablen
	set variablen_einzeldokument "
		NAME \"$name\"
		VSNR \"$vsnr\"
		BETRAG \"$betrag\"
		PICNR \"$picnr\"
		DATUMREZEPT \"$date\"
		REZEPTUR \"$rezeptur\"
		SUBSTANZ \"$substanz\"
		"

	# Ersetze die Platzhalter in der neuen Datei variabel!
	foreach {platzhalter ersetzung} $variablen_einzeldokument {
		regsub -all "$platzhalter" $texfile_variabel "$ersetzung" texfile_variabel
		#set texfile_variabel [string map -nocase "$platzhalter $ersetzung" $texfile_variabel]
	}

    # Kopiere die LaTeX-Datei
	exec echo $texfile_variabel > $new_file

}

# Schließe die CSV-Datei
close $csv


foreach file $tex_file_liste {
	# führendes "./" löschen
	set file [string range $file 2 end]
	set rootname [file rootname $file]
	# Codierung ändern!
	exec iconv -f UTF-8 -t ISO-8859-15//TRANSLIT $file -o $file
	exec pdflatex $file
	# Aufräumen!
	set log [string cat $rootname ".log"]
	exec rm $log
	set aux [string cat $rootname ".aux"]
	exec rm $aux
	exec rm $file
}
