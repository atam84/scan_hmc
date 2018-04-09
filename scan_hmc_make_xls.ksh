#!/usr/bin/env ksh

# atam on Github

if [ $# -ne 2 ]; then
        echo ""
        echo "Usage: $0 HMC_ADDRESS HMC_USER"
        echo ""
        exit 1
fi

# $0 hmc_address hmc_login
_hmc_address=${1}
_hmc_login=${2}
_hmc_password=""
_author="atam84"
_created_date=`date +'%Y-%m-%dT%H:%M:%SZ'`
_date=`date +'%Y-%m-%d_%H-%M-%S'`
_company="atam84"
_outputXLS="${_hmc_address}_${_date}_report.xls"
_tmp="table.xls"

function clean_up {
	echo "[Info] Clean up the old files"
	rm -f .* table.* *_report.xls 2>/dev/null
}

# read the password from keyboard
function read_password {
	while true; do
		stty -echo
		printf "[1/2] Please entre the password: "
		read _hmc_password
		printf "\n[2/2] Please re-entre the password: "
		read _PASSWORD_CONFIRMATION
		stty echo
		if [[ ${_hmc_password} == ${_PASSWORD_CONFIRMATION} ]]; then
			printf "\nPassword mutch OK\n"
			return 0
		else
			printf "\nPassword does not mutch [FAIL]\n"
			printf "Try again\n"
		fi
	done
}

clean_up
# getlist of managed system
echo "HMC Address : ${_hmc_address}"
echo "HMC Login   : ${_hmc_login}"

### Read password for HMC target
read_password

### Get list of operating managed systems
./get_hmc_data.exp ${_hmc_login} ${_hmc_password} ${_hmc_address} get_servers
#if [ $? -eq 10 ]; then
	sed -e '1d' -e '$d' .${_hmc_address}_powerstatus.tmp | sed 's/.$//' > .${_hmc_address}_powerstatus
	rm -f .${_hmc_address}_powerstatus.tmp
	_ManagedSys=`cat .${_hmc_address}_powerstatus | awk -F, '$3 ~ /Operating/ {printf "%s ", $1}'`
#fi

### Get configuration of memory, proc, lpar status and io slots
for _mng in ${_ManagedSys}; do
	echo "${_mng} Operating managed system"
	./get_hmc_data.exp ${_hmc_login} ${_hmc_password} ${_hmc_address} none ${_mng}
done

### remove the first line, the last line and ^M (\r) of data files
for _mng in ${_ManagedSys}; do
	for _f in `ls .${_mng}_*`; do
		_new_name=`echo ${_f} | sed 's/\.tmp$//'`
		sed -e '1d' -e '$d' -e 's/.$//' ${_f} > ${_new_name}
		### Remove temporary files
		if [ $? -eq 0 ]; then rm -f ${_f}; fi
	done
done

### Merge data files of io slots and hea interfaces
for _mng in ${_ManagedSys}; do
	for drawer in `awk -F, '{print $1}' .${_mng}_ioslot | sort -u`; do
		grep ${drawer} .${_mng}_ioslot >> .${_mng}_slots
		grep ${drawer} .${_mng}_hea >> .${_mng}_slots
	done
done

### Merge data files of lpar status, memory and procs
for _mng in ${_ManagedSys}; do
	_mem=".${_mng}_memory"
	_proc=".${_mng}_processors"
	_status=".${_mng}_lparstatus"
	awk -F, 'FILENAME==ARGV[1] {file_1_data[$1,$2]=$1","$2","$3;next;}
			($1,$2) in file_1_data {print file_1_data[$1,$2]","$3","$4","$5","$6;next;}' ${_status} ${_mem} > .state_mem.tmp
	
	awk -F, 'FILENAME==ARGV[1] {file_1_data[$1,$2]=$0;next;}
			($1,$2) in file_1_data {print file_1_data[$1,$2]","$3","$4","$5","$6","$7","$8","$9","$10","$11","$12","$13","$14;
			next;}' .state_mem.tmp ${_proc} > .${_mng}_ressources
	if [ -s .${_mng}_ressources ]; then
		echo "[Info] Ressources (lpar status, processors and memory) merged"
		rm -f ${_mem} ${_proc} ${_status} .state_mem.tmp
	else
		echo [ERROR] Fatal error occured
		echo "EXIT"
		exit 1
	fi
done



function Datasheet_styles {
## XML/XLS document header
echo '<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:html="http://www.w3.org/TR/REC-html40">
 <DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">
  <Author>'${_author}'</Author>
  <LastAuthor>'${_author}'</LastAuthor>
  <Created>'${_created_date}'</Created>
  <LastSaved>'${_created_date}'</LastSaved>
  <Company>'${_company}'</Company>
  <Version>15.00</Version>
 </DocumentProperties>
 <OfficeDocumentSettings xmlns="urn:schemas-microsoft-com:office:office">
  <AllowPNG/>
 </OfficeDocumentSettings>
 <ExcelWorkbook xmlns="urn:schemas-microsoft-com:office:excel">
  <WindowHeight>11595</WindowHeight>
  <WindowWidth>19200</WindowWidth>
  <WindowTopX>0</WindowTopX>
  <WindowTopY>0</WindowTopY>
  <ActiveSheet>1</ActiveSheet>
  <ProtectStructure>False</ProtectStructure>
  <ProtectWindows>False</ProtectWindows>
 </ExcelWorkbook>' > table.xls

## XML/XLS document styles
echo ' <Styles>
  <Style ss:ID="Default" ss:Name="Normal">
   <Alignment ss:Vertical="Bottom"/>
   <Borders/>
   <Font ss:FontName="Arial" x:Family="Swiss"/>
   <Interior/>
   <NumberFormat/>
   <Protection/>
  </Style>' >> table.xls

# Grid style
echo '    <Style ss:ID="s149">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#FFFFFF" ss:Pattern="ThinDiagStripe"
    ss:PatternColor="#000000"/>
  </Style>' >> table.xls

  # Big Title
echo '  <Style ss:ID="m405791176">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Font ss:FontName="Arial" x:Family="Swiss" ss:Size="18" ss:Bold="1"/>
  </Style>' >> table.xls

# Drawer cell style
echo '  <Style ss:ID="m405791196">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
  </Style>' >> table.xls

# Lpar id cell style
echo '  <Style ss:ID="s80">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Font ss:FontName="Arial" x:Family="Swiss" ss:Bold="1"/>
  </Style>' >> table.xls

# Lpar none cell style
echo '  <Style ss:ID="s81">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Font ss:FontName="Arial" x:Family="Swiss" ss:Bold="1"/>
   <Interior ss:Color="#BFBFBF" ss:Pattern="Solid"/>
  </Style>' >> table.xls

# Target cell style
echo '  <Style ss:ID="s73">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
  </Style>' >> table.xls

# Fibre channel cell style
echo '  <Style ss:ID="m405791216">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#9BC2E6" ss:Pattern="Solid"/>
  </Style>' >> table.xls

# Ethrnet cell style
echo '  <Style ss:ID="m405791236">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#FFD966" ss:Pattern="Solid"/>
  </Style>' >> table.xls
# SAS cell style
echo '  <Style ss:ID="m405791356">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#F4B084" ss:Pattern="Solid"/>
  </Style>' >> table.xls
# RAID cell style
echo '  <Style ss:ID="m405792732">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#C6E0B4" ss:Pattern="Solid"/>
  </Style>' >> table.xls
# Empty slot cell style
echo '  <Style ss:ID="m405793712">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#BFBFBF" ss:Pattern="Solid"/>
  </Style>' >> table.xls

# Memory style
echo '   <Style ss:ID="s129">
   <Alignment ss:Horizontal="Center" ss:Vertical="Bottom"/>
   <Borders>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#F8CBAD" ss:Pattern="Solid"/>
  </Style>' >> table.xls
# Lpar TAB style
echo '  <Style ss:ID="s148">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#BFBFBF" ss:Pattern="Solid"/>
  </Style>' >> table.xls
# PROC style
echo '  <Style ss:ID="s139">
   <Alignment ss:Horizontal="Center" ss:Vertical="Bottom"/>
   <Borders>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#FFE699" ss:Pattern="Solid"/>
  </Style>' >> table.xls
# Sub PROC TAB style
echo '  <Style ss:ID="s143">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#FFD966" ss:Pattern="Solid"/>
  </Style>' >> table.xls
# Sub memory TAB style
echo '  <Style ss:ID="s135">
   <Alignment ss:Horizontal="Center" ss:Vertical="Center" ss:WrapText="1"/>
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#F4B084" ss:Pattern="Solid"/>
  </Style>' >> table.xls
# Normal style
echo '  <Style ss:ID="s131">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
  </Style>' >> table.xls
# Running state style
echo '  <Style ss:ID="s140">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#92D050" ss:Pattern="Solid"/>
  </Style>' >> table.xls
# Not activated style
echo '  <Style ss:ID="s151">
   <Borders>
    <Border ss:Position="Bottom" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Left" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Right" ss:LineStyle="Continuous" ss:Weight="1"/>
    <Border ss:Position="Top" ss:LineStyle="Continuous" ss:Weight="1"/>
   </Borders>
   <Interior ss:Color="#E95959" ss:Pattern="Solid"/>
  </Style>' >> table.xls
 
 # END OF STYLES
 echo ' </Styles>' >> table.xls
}





function io_slot_units {
#lshwres -m CPU3-9117-MMB-SN066309P -r io --rsubtype slot -F unit_phys_loc,lpar_id,drc_name,description  | egrep -v "Universal Serial Bus|Generic XT-Compatable" | sed -e 's/PCI Express Dual Port Fibre Channel Adapter/FC/g' -e 's/Ethernet-TX PCI-E Adapter/Ethernet/g' -e 's/PCI-E //g'
_iofile=${1}
_system=${2}
echo "IO_SLOT_UNITS:"
echo "IO_FILE=${_iofile}"
echo "SYSTEM=${_system}"
index=10
for drawer in `cat ${_iofile} | awk -F, '/^\s*$/ { next;}{print $1}' | sort -u`; do
	index_plus=$((${index} + 5))
	grep ${drawer} ${_iofile} | sort -t, -nk3.23,3.24 | awk -F, -v drawer=${drawer} -v from_scratch=0 -v indx=${index} -v index_plus=${index_plus} '
	function get_target (str) {
		if (str ~ /-/) {
			c=split(str,array,"-"); out="";
			for (i=2; i<=c; i++) { out=sprintf ("%s%s", out, array[i]); if (i >= 2 && i < c) {out=sprintf ("%s-", out);;}}
		} else {
			out=sprintf ("%s", str);
		}
		return out;
	}
	/^\s*$/ { next;}
	$1 == drawer {
		if ($2 == "none") {	lpar_style="s81"; } else { lpar_style="s80"; }
		if ($4 ~ /FC/) {
			slot_style="m405791216"
		} else if ($4 ~ /Ethernet/) {
			slot_style="m405791236"
		} else if ($4 ~ /HEA/) {
			slot_style="m405791236"
		} else if ($4 ~ /Empty/) {
			slot_style="m405793712"
		} else if ($4 ~ /RAID/) {
			slot_style="m405792732"
		} else if ($4 ~ /SAS/) {
			slot_style="m405791356"
		} else {
			slot_style="s73"
		}
		drawer_style="m405791196"
		target_style="s73"

		if (from_scratch == 0) {
			printf "<Row ss:Index=\"%s\">\n", indx > "f1"
			printf "<Cell ss:Index=\"3\" ss:MergeDown=\"5\" ss:StyleID=\"%s\"><Data ss:Type=\"String\">%s</Data></Cell>\n", drawer_style, drawer > "f1"
			printf "<Cell ss:StyleID=\"%s\"><Data ss:Type=\"String\">%s</Data></Cell>\n", lpar_style, $2 > "f1"
			printf "<Row ss:AutoFitHeight=\"0\">" > "f2"
			printf "<Cell ss:Index=\"4\" ss:MergeDown=\"3\" ss:StyleID=\"%s\"><Data ss:Type=\"String\">%s</Data></Cell>\n", slot_style, $4 > "f2"
			printf "<Row ss:Index=\"%s\">", index_plus > "f3"
			printf "<Cell ss:Index=\"4\" ss:StyleID=\"%s\"><Data ss:Type=\"String\">%s</Data></Cell>\n", target_style, get_target($3) > "f3"
			from_scratch++;
		} else {
			printf "<Cell ss:StyleID=\"%s\"><Data ss:Type=\"String\">%s</Data></Cell>\n", lpar_style, $2 > "f1"
			printf "<Cell ss:MergeDown=\"3\" ss:StyleID=\"%s\"><Data ss:Type=\"String\">%s</Data></Cell>\n", slot_style, $4 > "f2"
                        printf "<Cell ss:StyleID=\"%s\"><Data ss:Type=\"String\">%s</Data></Cell>\n", target_style, get_target($3) > "f3"
		}
	}'
	from_scratch=0;
	echo "</Row>" >> f1
	echo "</Row>" >> f2
	echo "</Row>" >> f3
	index=$((${index_plus} + 3))
	cat f1 >> table.txt
	cat f2 >> table.txt
	cat f3 >> table.txt
done

ExpandedRowCount=$(($index - 3))
echo ' <Worksheet ss:Name="IO '${_system}'">'  >> table.xls
echo "  <Table ss:ExpandedColumnCount=\"50\" ss:ExpandedRowCount=\"${ExpandedRowCount}\" x:FullColumns=\"1\" x:FullRows=\"1\" ss:DefaultColumnWidth=\"60\">" >> table.xls
echo "   <Column ss:Index=\"3\" ss:Width=\"92.25\"/>"  >> table.xls
echo "   <Row ss:Index=\"2\">"  >> table.xls
echo "    <Cell ss:Index=\"4\" ss:MergeAcross=\"7\" ss:MergeDown=\"3\" ss:StyleID=\"m405791176\"><Data ss:Type=\"String\">${_system} IO SLOTS</Data></Cell>"  >> table.xls
echo "   </Row>"  >> table.xls

cat table.txt >> table.xls

echo '  </Table>
  <WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">
   <PageSetup>
    <Header x:Margin="0.3"/>
    <Footer x:Margin="0.3"/>
    <PageMargins x:Bottom="0.75" x:Left="0.7" x:Right="0.7" x:Top="0.75"/>
   </PageSetup>
   <Selected/>
   <Panes>
    <Pane>
     <Number>3</Number>
     <ActiveRow>35</ActiveRow>
     <ActiveCol>4</ActiveCol>
    </Pane>
   </Panes>
   <ProtectObjects>False</ProtectObjects>
   <ProtectScenarios>False</ProtectScenarios>
  </WorksheetOptions>
 </Worksheet>' >> table.xls
 rm -f f1 f2 f3 table.txt
}



function mem_proc_ressources {
_resfile=${1}
_system=${2}
echo "MEM PROC RESSOURCES:"
echo "RES_FILE=${_resfile}"
echo "SYSTEM=${_system}"
echo ' <Worksheet ss:Name="RES '${_system}'">
  <Table ss:ExpandedColumnCount="19" ss:ExpandedRowCount="300" x:FullColumns="1" x:FullRows="1" ss:DefaultColumnWidth="60">
   <Column ss:Index="4" ss:AutoFitWidth="0" ss:Width="48.75"/>
   <Column ss:AutoFitWidth="0" ss:Width="38.25"/>
   <Column ss:AutoFitWidth="0" ss:Width="45.75"/>
   <Column ss:Width="32.25"/>
   <Column ss:AutoFitWidth="0" ss:Width="48.75"/>
   <Column ss:AutoFitWidth="0" ss:Width="45.75"/>
   <Column ss:AutoFitWidth="0" ss:Width="49.5"/>
   <Column ss:AutoFitWidth="0" ss:Width="42.75"/>
   <Column ss:AutoFitWidth="0" ss:Width="40.5"/>
   <Column ss:AutoFitWidth="0" ss:Width="44.25"/>
   <Column ss:AutoFitWidth="0" ss:Width="47.25"/>
   <Column ss:AutoFitWidth="0" ss:Width="46.5"/>
   <Column ss:Index="17" ss:AutoFitWidth="0" ss:Width="42.75"/>
   <Column ss:AutoFitWidth="0" ss:Width="39"/>
   <Column ss:AutoFitWidth="0" ss:Width="52.5"/>
   <Row>
    <Cell ss:Index="4" ss:MergeAcross="3" ss:StyleID="s129"><Data ss:Type="String">Memory</Data></Cell>
    <Cell ss:MergeAcross="11" ss:StyleID="s139"><Data ss:Type="String">Proc</Data></Cell>
   </Row>
   <Row ss:AutoFitHeight="0" ss:Height="37.5">
    <Cell ss:StyleID="s148"><Data ss:Type="String">Lpar name</Data></Cell>
    <Cell ss:StyleID="s148"><Data ss:Type="String">Lpar ID</Data></Cell>
    <Cell ss:StyleID="s148"><Data ss:Type="String">State</Data></Cell>
    <Cell ss:StyleID="s135"><Data ss:Type="String">min mem</Data></Cell>
    <Cell ss:StyleID="s135"><Data ss:Type="String">Current</Data></Cell>
    <Cell ss:StyleID="s135"><Data ss:Type="String">max mem</Data></Cell>
    <Cell ss:StyleID="s135"><Data ss:Type="String">mode</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">min proc units</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">proc units</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">max proc units</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">min procs</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">procs</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">max procs</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">sharing mode</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">uncap weight</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">pend shared proc pool name</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">run proc units</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">run procs</Data></Cell>
    <Cell ss:StyleID="s143"><Data ss:Type="String">run uncap weight</Data></Cell>
   </Row>
' >> table.xls

cat ${_resfile} | awk -F, '
	        BEGIN {
			r_min_mem=0;
			r_curr_mem=0;
			r_max_mem=0;
			r_procs=0;
			r_min_procs=0;
			r_max_procs=0;
			r_run_proc_units=0;
			r_run_procs=0;
			r_run_uncap=0;
			
			rr_min_procs=0;
			rr_procs=0;
			rr_max_procs=0;
			r_uncap_weight=0;
			
			n_min_mem=0;
			n_curr_mem=0;
			n_max_mem=0;
			n_procs=0;
			n_min_procs=0;
			n_max_procs=0;
			n_run_proc_units=0;
			n_run_procs=0;
			n_run_uncap=0;
			
			nr_min_procs=0;
			nr_procs=0;
			nr_max_procs=0;
			n_uncap_weight=0;
        }
        {
			printf "   <Row>\n";
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"String\">%s</Data></Cell>\n", $1;
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $2;
			if ($3 == "Running") {
					printf "    <Cell ss:StyleID=\"s140\"><Data ss:Type=\"String\">%s</Data></Cell>\n", $3;
			} else {
					printf "    <Cell ss:StyleID=\"s151\"><Data ss:Type=\"String\">%s</Data></Cell>\n", $3;
			}

			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $4;  # min mem
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $5;  # Current
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $6;  # max mem
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"String\">%s</Data></Cell>\n", $7;  # mode
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $8;  # min proc units
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $9;  # proc units
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $10; # max proc units
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $11; # min procs
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $12; # procs
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $13; # max procs
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"String\">%s</Data></Cell>\n", $14; # sharing mode
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $15; # uncap weight
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"String\">%s</Data></Cell>\n", $16; # pend shared proc pool name
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $17; # run proc units
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $18; # run procs
			printf "    <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", $19; # run uncap weight
			printf "   </Row>\n";
			last_cell=NR;
			if ($3 == "Running") {
				r_min_mem=r_min_mem+$4
				r_curr_mem=r_curr_mem+$5
				r_max_mem=r_max_mem+$6
				r_min_procs=r_min_procs+$8
				r_procs=r_procs+$9;
				r_max_procs=r_max_procs+$10;
				
				rr_min_procs=rr_min_procs+$11;
				rr_procs=rr_procs+$12;
				rr_max_procs=rr_max_procs+$13;
				r_uncap_weight=r_uncap_weight+$15;
				
				r_run_proc_units=r_run_proc_units+$17;
				r_run_procs=r_run_procs+$18;
				r_run_uncap=r_run_uncap+$19;
			} else {
				n_min_mem=n_min_mem+$4
				n_curr_mem=n_curr_mem+$5
				n_max_mem=n_max_mem+$6
				n_min_procs=n_min_procs+$8
				n_procs=n_procs+$9;
				n_max_procs=n_max_procs+$10;
				
				nr_min_procs=nr_min_procs+$11
				nr_procs=nr_procs+$12
				nr_max_procs=nr_max_procs+$13
				n_uncap_weight=n_uncap_weight+$15;
				
				n_run_proc_units=n_run_proc_units+$17;
				n_run_procs=n_run_procs+$18;
				n_run_uncap=n_run_uncap+$19;
			}
        }
        END {
			printf "       <Row ss:Index=\"%s\">", last_cell+4;
			printf "        <Cell ss:Index=\"3\" ss:StyleID=\"s148\"><Data ss:Type=\"String\">Total</Data></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", (r_min_mem + n_min_mem)/1024;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", (r_curr_mem + n_curr_mem)/1024;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", (r_max_mem + n_max_mem)/1024;
			printf "        <Cell ss:StyleID=\"s149\"></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_min_procs + n_min_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_procs + n_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_max_procs + n_max_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", rr_min_procs + nr_min_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", rr_procs + nr_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", rr_max_procs + nr_max_procs;
			printf "        <Cell ss:StyleID=\"s149\"></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_uncap_weight + n_uncap_weight;
			printf "        <Cell ss:StyleID=\"s149\"></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_run_proc_units + n_run_proc_units;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_run_procs + n_run_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_run_uncap + n_run_uncap;
			printf "       </Row>\n";
			printf "       <Row>\n";
			printf "        <Cell ss:Index=\"3\" ss:StyleID=\"s148\"><Data ss:Type=\"String\">Running</Data></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_min_mem/1024;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_curr_mem/1024;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_max_mem/1024;
			printf "        <Cell ss:StyleID=\"s149\"></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_min_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_max_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", rr_min_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", rr_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", rr_max_procs;
			printf "        <Cell ss:StyleID=\"s149\"></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_uncap_weight;
			printf "        <Cell ss:StyleID=\"s149\"></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_run_proc_units;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_run_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", r_run_uncap;
			printf "       </Row>\n";
			printf "       <Row>\n";
			printf "        <Cell ss:Index=\"3\" ss:StyleID=\"s148\"><Data ss:Type=\"String\">Not active</Data></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", n_min_mem/1024;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", n_curr_mem/1024;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", n_max_mem/1024;
			printf "        <Cell ss:StyleID=\"s149\"></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", n_min_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", n_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", n_max_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", nr_min_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", nr_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", nr_max_procs;
			printf "        <Cell ss:StyleID=\"s149\"></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", n_uncap_weight;
			printf "        <Cell ss:StyleID=\"s149\"></Cell>\n";
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", n_run_proc_units;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", n_run_procs;
			printf "        <Cell ss:StyleID=\"s131\"><Data ss:Type=\"Number\">%s</Data></Cell>\n", n_run_uncap;
			printf "       </Row>\n";
        }' >> table.xls

echo '  </Table>
  <WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">
   <PageSetup>
    <Header x:Margin="0.3"/>
    <Footer x:Margin="0.3"/>
    <PageMargins x:Bottom="0.75" x:Left="0.7" x:Right="0.7" x:Top="0.75"/>
   </PageSetup>
   <Selected/>
   <Panes>
    <Pane>
     <Number>3</Number>
     <ActiveRow>23</ActiveRow>
     <ActiveCol>4</ActiveCol>
    </Pane>
   </Panes>
   <ProtectObjects>False</ProtectObjects>
   <ProtectScenarios>False</ProtectScenarios>
  </WorksheetOptions>
 </Worksheet>' >> table.xls
}



Datasheet_styles

for _mng in ${_ManagedSys}; do
	io_slot_units .${_mng}_slots ${_mng}
	mem_proc_ressources .${_mng}_ressources ${_mng}
done

echo "</Workbook>" >> ${_tmp}

sed -e 's/<Data ss:Type=\"Number\">null<\/Data>/<Data ss:Type=\"Number\">0<\/Data>/g' ${_tmp} > ${_outputXLS}

rm -f f* table.txt ${_tmp}

