# Топ суммарно длительных вызовов
# Суммарная длительность :: База :: Вызов
echo $(date);
rphostFilter="rphost_*";
echo rphostFilter $rphostFilter;
cat $rphostFilter/*.log | \
#head -n 10000 | \
awk -vORS= '{if(match($0, "^[0-9][0-9]\:[0-9][0-9]\.[0-9]+\-")) print "\n"$0; else print $0;}' | \
perl -pe 's/\xef\xbb\xbf//g' | \
grep -P ',.*CALL,.*p:processName=ERP.*' | \
awk '{
 posDlit = match($0, "-");
 posCALL = match($0, ",.*CALL");
 LenDlit = posCALL - posDlit;
 dlit = substr($0, posDlit+1, LenDlit); #длительность вызова (для 8.2 1/10000 секунд, для 8.3 1/1000000 секунд)
 dlit = dlit / 1000000;
 
 posMemory = match($0, ",Memory=");
 posMemoryPeak = match($0, ",MemoryPeak=");
 posInBytes = match($0, ",InBytes=");
 posOutBytes = match($0, ",OutBytes=");
 
 Memory = substr($0, posMemory + 8, (posMemoryPeak - posMemory - 8));
 
 ToAdd = 0; # определяет, выполнять ли проверку в массиве и добавление, т.е. пропускать строку или нет
 
 posFunc = match($0, ",Func=");
 if(posFunc!=0) # у регламентных заданий так
 { 
  ToAdd = 1;
  posSessionID = match($0, ",SessionID");
  posUsr = match($0, ",Usr");
  UsrName = substr($0, posUsr + 1, (posSessionID - posUsr - 1));
  
  posBase = match($0, "p:processName=");
  LenBase = posFunc - posBase;
  pBase = substr($0, posBase, LenBase);
  gsub("p:processName", "Base", pBase);
  posMemory = match($0, ",Memory=");
  posModule = match($0, ",Module=");
  LenMethod = posMemory - posModule;
  Method = substr($0, posModule + 1, LenMethod - 1);
  #UsrName = "";
  KeyStr = pBase " :: " Method " :: " UsrName; 
 }
 if(posFunc==0) # у пользовательских вызовов так
 {
  posContext = match($0, ",Context=");
  if(posContext!=0)
  {
   ToAdd = 1;
   posBase = match($0, "p:processName=");
   postClientID = match($0, ",t:clientID=");
   LenBase = postClientID - posBase;
   pBase = substr($0, posBase, LenBase);
   gsub("p:processName", "Base", pBase);
   strContexMore = substr($0, posContext+1);
   posEndContext = match(strContexMore, ",");
   Context = substr(strContexMore, 1, posEndContext);
   KeyStr = pBase " :: " Context;
  }
 }
 
 if(ToAdd==1)
 {
	posOutBytes = match($0, ",OutBytes=");
	OutBytes = substr($0, posOutBytes + length(",OutBytes="));
	posInBytes = match($0, ",InBytes=");
	InBytes = substr($0, posInBytes + length(",InBytes="), posOutBytes - posInBytes - length(",InBytes="));
	posMemoryPeak = match($0, ",MemoryPeak=");
	MemoryPeak = substr($0, posMemoryPeak + length(",MemoryPeak="), posInBytes - posMemoryPeak - length(",MemoryPeak="));
	posMemory = match($0, ",Memory=");
	Memory = substr($0, posMemory + length(",Memory="), posMemoryPeak - posMemory - length(",Memory="));	
  
	arr_dlits[KeyStr] += dlit;
	#arr_memories[KeyStr] += Memory;
	arr_counts[KeyStr] +=1;
	arr_OutBytes[KeyStr] += OutBytes / 1024 / 1024;
	arr_InBytes[KeyStr] += InBytes / 1024 / 1024;
	arr_MemoryPeak[KeyStr] += MemoryPeak / 1024 / 1024;
	arr_Memory[KeyStr] += Memory / 1024 / 1024;
 } 
} END {
	for (i in arr_dlits) {printf "\t****%8d sec %5d min %8.2f avrg %6d cnt %5d OutMB %5d InMB %6d MBMemPeak %6d MBMem %s\n", arr_dlits[i],
	(arr_dlits[i])/60, arr_dlits[i] / arr_counts[i], arr_counts[i], arr_OutBytes[i], arr_InBytes[i], arr_MemoryPeak[i], arr_Memory[i], i}
}' | sort -rnb | head -n 30;
echo $(date);