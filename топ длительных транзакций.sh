echo $(date);
rphostFilter="rphost_*";
echo rphostFilter $rphostFilter;
cat $rphostFilter/*.log | \
#head -n 100000 | \
awk -vORS= '{if(match($0, "^[0-9][0-9]\:[0-9][0-9]\.[0-9]+\-")) print "\n"$0; else print $0 "<line>";}' | \
perl -pe 's/\xef\xbb\xbf//g' | \
grep -P "SDBL.*Func=(Commit|Rollback)Transaction.*Context" | \
perl -pe 's/^\d+:\d+.\d+-//g' | \
#perl -pe 's/,SDBL,.*Context/,Context/g' | \
perl -pe 's/Context.*<line>[ \t]+/Context=/g' | \
perl -pe 's/<line>//g' | \
awk '{
	posContext = match($0, ",Context=");
		
	Context = substr($0, posContext + length(",Context="));
	Context = substr(Context, 1, length(Context));
	
	posProcessName = match($0, ",p:processName=");
	posclientID = match($0, ",t:clientID=");
	
	BaseName = substr($0, posProcessName + length(",p:processName="), posclientID - posProcessName - length(",p:processName="));
	
	posTrans = match($0, ",Trans");
	posUsr = match($0, ",Usr");
	UsrName = substr($0, posUsr + 1, (posTrans - posUsr - 1));
	
	Context = BaseName " :: " Context " :: " UsrName;
	
	dlit = substr($0, 1, posContext);
	dlit = dlit / 1000000;
		
	if(dlit > 1) {
		sum[Context]+=dlit; count[Context]+=1;
	}
} END {
	for(i in sum) {
		printf "\t****%7d sec %5d min %7.2f avrg %5d cnt %s\n", sum[i], sum[i] / 60, sum[i]/count[i], count[i], i
	}
}' | \
sort -rnb | head -n 30;
echo $(date);