#!/bin/bash

LANG=C
PROG=${0}

SUDOUSER=${SUDO_USER:-$(whoami)}
eval SUDOUSERHOME=~$SUDOUSER

# ==============================================================================
# Parameter Processing
# ==============================================================================
Usage() {
cat <<EOF
Usage: $PROG [OPTION] <AnswerFile Template dir>

Options for windows anwserfile:
  --hostname    #hostname of Windows Guest VM; e.g: win2019-ad
  --domain <domain>
		#*Specify windows domain name; e.g: qetest.org

  -u, --user <user>
		#Specify user for install and config.
		  default value: Administrator
  -p, --password <password>
		#*Specify user's password for windows. for configure AD/DC:
		  must use a mix of uppercase letters, lowercase letters, numbers, and symbols
		  default value: Sesame~0pen

  --path <answer file image path>
		#e.g: --path /path/to/ansf-usb.image
  --wim-index <wim image index>
  --product-key #Prodcut key for windows activation.

  --ad-forest-level <Default|Win2008|Win2008R2|Win2012|Win2012R2|WinThreshold>
		#Specify active directory forest level.
		  Windows Server 2003: 2 or Win2003
		  Windows Server 2008: 3 or Win2008
		  Windows Server 2008 R2: 4 or Win2008R2
		  Windows Server 2012: 5 or Win2012
		  Windows Server 2012 R2: 6 or Win2012R2
		  Windows Server 2016: 7 or WinThreshold
		#The default forest functional level in Windows Server is typically the same -
		#as the version you are running. However, the default forest functional level -
		#in Windows Server 2008 R2 when you create a new forest is Windows Server 2003 or 2.
		#see: https://docs.microsoft.com/en-us/powershell/module/addsdeployment/install-addsforest?view=win10-ps
  --ad-domain-level <Default|Win2008|Win2008R2|Win2012|Win2012R2|WinThreshold>
		#Specify active directory domain level.
		  Windows Server 2003: 2 or Win2003
		  Windows Server 2008: 3 or Win2008
		  Windows Server 2008 R2: 4 or Win2008R2
		  Windows Server 2012: 5 or Win2012
		  Windows Server 2012 R2: 6 or Win2012R2
		  Windows Server 2016: 7 or WinThreshold
		#The domain functional level cannot be lower than the forest functional level,
		#but it can be higher. The default is automatically computed and set.
		#see: https://docs.microsoft.com/en-us/powershell/module/addsdeployment/install-addsforest?view=win10-ps
  --enable-kdc  #enable AD KDC service(in case use AnswerFileTemplates/cifs-nfs/postinstall.ps1)
		#- to do nfs/cifs krb5 test
  --parent-domain <parent-domain>
		#Domain name of an existing domain, only for template: 'addsdomain'
  --parent-ip <parent-ip>
		#IP address of an existing domain, only for template: 'addsdomain'
  --dfs-target <server:sharename>
		#The specified cifs share will be added into dfs target.
  --openssh <url>
		#url to download OpenSSH-Win64.zip
  --driver-url,--download-url <url>
		#url to download extra drivers to anserfile media:
		#e.g: --driver-url=urlX --driver-url=urlY
  --run,--run-with-reboot <command line>
		#powershell cmd line need autorun and reboot
		#e.g: --run='./MLNX_VPI_WinOF-5_50_54000_All_win2019_x64.exe /S /V"qb /norestart"'
  --run-post <command line>
		#powershell cmd line need autorun without reboot
		#e.g: --run-post='ipconfig /all; ibstat'
  --static-ip-ext <>
		#set static ip for the nic that connect to public network
  --static-ip-int <>
		#set static ip for the nic that connect to internal libvirt network

Examples:
  #create answer file usb for Active Directory forest Win2012r2:
  $PROG --hostname win2012-adf --domain ad.test   --product-key W3GGN-FT8W3-Y4M27-J84CP-Q3VJ9 \\
	-p ~Ocgxyz --ad-forest-level Win2012R2 \\
	--openssh=https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip \\
	./AnswerFileTemplates/addsforest --path ./ansf-usb.image
  vm create Windows-Server-2012 -n win2012-adf -C /home/download/Win2012r2-Evaluation.iso \\
	--disk ansf-usb.image,bus=usb \\
	--net=default,model=rtl8139 --net-macvtap=-,model=e1000 \\
	--diskbus sata
  #Note: about 'vm create' see: https://github.com/tcler/kiss-vm-ns

  #create answer file usb for Active Directory child domain:
  $PROG --hostname win2016-adc --domain fs.qe \\
	-p ~Ocgxyz --parent-domain kernel.test --parent-ip \$addr \\
	--openssh=https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip \\
	./AnswerFileTemplates/addsdomain --path ./ansf-usb.image
  vm create Windows-Server-2016 -n win2016-adc -C /home/download/Win2016-Evaluation.iso \\
	--disk ansf-usb.image,bus=usb \\
	--net=default,model=rtl8139 --net-macvtap=-,model=e1000 \\
	--diskbus sata

  #create answer file usb for Windows NFS/CIFS server, and enable KDC(--enable-kdc):
  $PROG --hostname win2019-nfs --domain cifs-nfs.test \\
	-p ~Ocgxyz --enable-kdc \\
	--openssh=https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip \\
	./AnswerFileTemplates/cifs-nfs --path ./ansf-usb.image
  vm create Windows-Server-2019 -n win2019-nfs -C /home/download/Win2019-Evaluation.iso \\
	--disk ansf-usb.image,bus=usb \\
	--net=default,model=rtl8139 --net-macvtap=-,model=e1000 \\
	--diskbus sata

  #create answer file usb for Windows NFS/CIFS server, and install mellanox driver:
  $PROG --hostname win2019-rdma --domain nfs-rdma.test \\
	-p ~Ocgxyz \\
	--openssh=https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip \\
	--driver-url=http://www.mellanox.com/downloads/WinOF/MLNX_VPI_WinOF-5_50_54000_All_win2019_x64.exe \\
	--run-with-reboot='./MLNX_VPI_WinOF-5_50_54000_All_win2019_x64.exe /S /V\"/qb /norestart\"' \\
	--run-post='ipconfig /all; ibstat' \\
	./AnswerFileTemplates/cifs-nfs --path ./ansf-usb.image
  vm create Windows-Server-2019 -n win2019-rdma -C /home/download/Win2019-Evaluation.iso \\
	--disk ansf-usb.image,bus=usb \\
	--net=default,model=rtl8139 --net-macvtap=-,model=e1000 \\
	--diskbus sata

  #create answer file usb for Windows NFS/CIFS server, and add dfs target, and enable KDC(--enable-kdc):
  $PROG --hostname win2019-dfs --domain cifs-nfs.test \\
	-p ~Ocgxyz --dfs-target \$hostname:\$cifsshare --enable-kdc \\
	--openssh=https://github.com/PowerShell/Win32-OpenSSH/releases/download/V8.6.0.0p1-Beta/OpenSSH-Win64.zip \\
	./AnswerFileTemplates/cifs-nfs --path ./ansf-usb.image
  vm create Windows-Server-2019 -n win2019-dfs -C /home/download/Win2019-Evaluation.iso \\
	--disk ansf-usb.image,bus=usb \\
	--net=default,model=rtl8139 --net-macvtap=-,model=e1000 \\
	--diskbus sata

EOF
}

ARGS=$(getopt -o hu:p: \
	--long help \
	--long path: \
	--long user: \
	--long password: \
	--long wim-index: \
	--long product-key: \
	--long hostname: \
	--long domain: \
	--long ad-forest-level: \
	--long ad-domain-level: \
	--long static-ip-ext: \
	--long static-ip-int: \
	--long enable-kdc \
	--long parent-domain: \
	--long parent-ip: \
	--long openssh: \
	--long driver-url: --long download-url: \
	--long run: --long run-with-reboot: \
	--long run-post: \
	--long dfs-target: \
	-a -n "$PROG" -- "$@")
eval set -- "$ARGS"
while true; do
	case "$1" in
	-h|--help) Usage; exit 1;; 
	--path) ANSF_IMG_PATH="$2"; shift 2;;
	-u|--user) ADMINUSER="$2"; shift 2;;
	-p|password) ADMINPASSWORD="$2"; shift 2;;
	--wim-index) WIM_IMAGE_INDEX="$2"; shift 2;;
	--product-key) PRODUCT_KEY="$2"; shift 2;;
	--hostname) GUEST_HOSTNAME="$2"; shift 2;;
	--domain) DOMAIN="$2"; shift 2;;
	--ad-forest-level) AD_FOREST_LEVEL="$2"; shift 2;;
	--ad-domain-level) AD_DOMAIN_LEVEL="$2"; shift 2;;
	--static-ip-ext) EXT_STATIC_IP="$2"; shift 2;;
	--static-ip-int) INT_STATIC_IP="$2"; shift 2;;
	--enable-kdc) KDC_OPT="-kdc"; shift 1;;
	--parent-domain) PARENT_DOMAIN="$2"; shift 2;;
	--parent-ip) PARENT_IP="$2"; shift 2;;
	--openssh) OpenSSHUrl="$2"; shift 2;;
	--driver-url|--download-url) DL_URLS+=("$2"); shift 2;;
	--run|--run-with-reboot) RUN_CMDS+=("$2"); shift 2;;
	--run-post) RUN_POST_CMDS+=("$2"); shift 2;;
	--dfs-target) DFS_TARGET="$2"; DFS=yes; shift 2;;
	--) shift; break;;
	*) Usage; exit 1;; 
	esac
done

AD_FOREST_LEVEL=${AD_FOREST_LEVEL:-Default}
AD_DOMAIN_LEVEL=${AD_DOMAIN_LEVEL:-$AD_FOREST_LEVEL}
DefaultAnserfileTemplatePath=/usr/share/make-windows-vm/AnswerFileTemplates/base
[[ -d "$DefaultAnserfileTemplatePath" ]] || DefaultAnserfileTemplatePath=AnswerFileTemplates/base
AnserfileTemplatePath=${1%/}
if [[ -z "$AnserfileTemplatePath" ]]; then
	AnserfileTemplatePath=$DefaultAnserfileTemplatePath
	echo "{warn} no answer files template is given, use default($DefaultAnserfileTemplatePath)" >&2
fi

if [[ ! -d "$AnserfileTemplatePath" ]]; then
	echo "{ERROR} template dir($AnserfileTemplatePath) not found" >&2
	exit 1
fi

if egrep -q "@PARENT_(DOMAIN|IP)@" -r "$AnserfileTemplatePath"; then
	[[ -z "$PARENT_DOMAIN" || -z "$PARENT_IP" ]] && {
		echo "{ERROR} Missing parent-domain or parent-ip for template(${AnserfileTemplatePath##*/})" >&2
		Usage >&2
		exit 1
	}
fi

[[ -z "$PRODUCT_KEY" ]] && {
	echo -e "{WARN} *** There is no Product Key specified, We assume that you are using evaluation version."
	echo -e "{WARN} *** Otherwise please use the '--product-key <key>' to ensure successful installation."
}

curl_download() {
	local filename=$1
	local url=$2
	shift 2;

	local curlopts="-f -L"
	local header=
	local fsizer=1
	local fsizel=0
	local rc=

	[[ -z "$filename" || -z "$url" ]] && {
		echo "Usage: curl_download <filename> <url> [curl options]" >&2
		return 1
	}

	header=$(curl -L -I -s $url|sed 's/\r//')
	fsizer=$(echo "$header"|awk '/Content-Length:/ {print $2; exit}')
	if echo "$header"|grep -q 'Accept-Ranges: bytes'; then
		curlopts+=' --continue-at -'
	fi

	echo "{INFO} run: curl -o $filename ${url} $curlopts $curlOpt $@"
	curl -o $filename $url $curlopts $curlOpt "$@"
	rc=$?
	if [[ $rc != 0 && -s $filename ]]; then
		fsizel=$(stat --printf %s $filename)
		if [[ $fsizer -le $fsizel ]]; then
			echo "{INFO} *** '$filename' already exist $fsizel/$fsizer"
			rc=0
		fi
	fi

	return $rc
}
curl_download_x() { until curl_download "$@"; do sleep 1; done; }

# =======================================================================
# Global variable
# =======================================================================
IPCONFIG_LOGF=ipconfig.log
INSTALL_COMPLETE_FILE=installcomplete
POST_INSTALL_LOGF=postinstall.log
VIRTHOST=$(
for H in $(hostname -A); do
	if [[ ${#H} > 15 && $H = *.*.* ]]; then
		echo $H;
		break;
	fi
done)
[[ -z "$VIRTHOST" ]] && {
	_ipaddr=$(getDefaultIp4)
	VIRTHOST=$(host ${_ipaddr%/*} | awk '{print $NF; exit}')
	VIRTHOST=${VIRTHOST%.}
	[[ "$VIRTHOST" = *NXDOMAIN* ]] && {
		VIRTHOST=$_ipaddr
	}
}

# =======================================================================
# Windows Preparation
# =======================================================================
WIM_IMAGE_INDEX=${WIM_IMAGE_INDEX:-4}
[[ "$VM_OS_VARIANT" = win10 ]] && WIM_IMAGE_INDEX=1
GUEST_HOSTNAME=${GUEST_HOSTNAME}
[[ -z "$GUEST_HOSTNAME" ]] && {
	echo -e "{ERROR} you are missing --hostname=<vm-hostname> option, it is necessary" >&2
	Usage >&2
	exit 1
}
[[ ${#GUEST_HOSTNAME} -gt 15 ]] && {
	echo -e "{ERROR} length of hostname($GUEST_HOSTNAME) should < 16" >&2
	exit 1
}
DOMAIN=${DOMAIN:-win.com}
ADMINUSER=${ADMINUSER:-Administrator}
ADMINPASSWORD=${ADMINPASSWORD:-Sesame~0pen}

# Setup Active Directory
FQDN=$GUEST_HOSTNAME.$DOMAIN
[[ -n "$PARENT_DOMAIN" ]] && FQDN+=.$PARENT_DOMAIN
NETBIOS_NAME=$(echo ${DOMAIN//./} | tr '[a-z]' '[A-Z]')
NETBIOS_NAME=${NETBIOS_NAME:0:15}

# anwser file usb image path ...
ANSF_IMG_PATH=${ANSF_IMG_PATH:-ansf-usb.image}

# ====================================================================
# Generate answerfiles media(USB)
# ====================================================================
process_ansf() {
	local destdir=$1; shift
	for f; do fname=${f##*/}; cp ${f} $destdir/${fname%.in}; done

	sed -i -e "s/@ADMINPASSWORD@/$ADMINPASSWORD/g" \
		-e "s/@ADMINUSER@/$ADMINUSER/g" \
		-e "s/@AD_DOMAIN@/$DOMAIN/g" \
		-e "s/@NETBIOS_NAME@/$NETBIOS_NAME/g" \
		-e "s/@VM_NAME@/$VM_NAME/g" \
		-e "s/@FQDN@/$FQDN/g" \
		-e "s/@PRODUCT_KEY@/$PRODUCT_KEY/g" \
		-e "s/@WIM_IMAGE_INDEX@/$WIM_IMAGE_INDEX/g" \
		-e "s/@ANSF_DRIVE_LETTER@/$ANSF_DRIVE_LETTER/g" \
		-e "s/@INSTALL_COMPLETE_FILE@/$INSTALL_COMPLETE_FILE/g" \
		-e "s/@AD_FOREST_LEVEL@/$AD_FOREST_LEVEL/g" \
		-e "s/@AD_DOMAIN_LEVEL@/$AD_DOMAIN_LEVEL/g" \
		-e "s/@VNIC_INT_MAC@/$MAC_INT/g" \
		-e "s/@VNIC_EXT_MAC@/$MAC_EXT/g" \
		-e "s/@INT_STATIC_IP@/$INT_STATIC_IP/g" \
		-e "s/@EXT_STATIC_IP@/$EXT_STATIC_IP/g" \
		-e "s/@VIRTHOST@/$VIRTHOST/g" \
		-e "s/@IPCONFIG_LOGF@/$IPCONFIG_LOGF/g" \
		-e "s/@GUEST_HOSTNAME@/$GUEST_HOSTNAME/g" \
		-e "s/@POST_INSTALL_LOG@/C:\\\\$POST_INSTALL_LOGF/g" \
		-e "s/@KDC_OPT@/$KDC_OPT/g" \
		-e "s/@PARENT_DOMAIN@/$PARENT_DOMAIN/g" \
		-e "s/@PARENT_IP@/$PARENT_IP/g" \
		-e "s/@DFS_TARGET@/$DFS_TARGET/g" \
		-e "s/@HOST_NAME@/$HOSTNAME/g" \
		-e "s/@AUTORUN_DIR@/$ANSF_AUTORUN_DIR/g" \
		$destdir/*
	[[ -z "$PRODUCT_KEY" ]] && {
		echo -e "{INFO} remove ProductKey node from xml ..."
		sed -i '/<ProductKey>/ { :loop /<\/ProductKey>/! {N; b loop}; s;<ProductKey>.*</ProductKey>;; }' $destdir/*.xml
	}
	unix2dos $destdir/* >/dev/null

	[[ -n "$OpenSSHUrl" ]] && curl_download_x $destdir/OpenSSH.zip $OpenSSHUrl
	cp $SUDOUSERHOME/.ssh/id_*.pub $destdir/. 2>/dev/null

	autorundir=$destdir/$ANSF_AUTORUN_DIR
	if [[ -n "$DL_URLS" ]]; then
		mkdir -p $autorundir
		for _url in "${DL_URLS[@]}"; do
			_fname=${_url##*/}
			curl_download_x $autorundir/${_fname} $_url
		done
	fi
	if [[ -n "$RUN_CMDS" || -n "$RUN_POST_CMDS" ]]; then
		mkdir -p $autorundir
		runf=$autorundir/autorun.ps1
		runpostf=$autorundir/autorun-post.ps1
		for _cmd in "${RUN_CMDS[@]}"; do
			echo "$_cmd" >>$runf
		done
		for _cmd in "${RUN_POST_CMDS[@]}"; do
			echo "$_cmd" >>$runpostf
		done
		unix2dos $runf $runpostf >/dev/null
	fi
}

echo -e "\n{INFO} make answer file media ..."
eval "ls $AnserfileTemplatePath/*" || {
	echo -e "\n{ERROR} answer files not found in $AnserfileTemplatePath"
	exit 1
}
\rm -f $ANSF_IMG_PATH #remove old/exist media file

ANSF_DRIVE_LETTER="D:"
ANSF_AUTORUN_DIR=tools-drivers
usbSize=1024M
media_dir=$(mktemp -d)
trap "rm -fr $media_dir" EXIT
process_ansf $media_dir $AnserfileTemplatePath/*
virt-make-fs -s $usbSize -t vfat $media_dir $ANSF_IMG_PATH --partition
