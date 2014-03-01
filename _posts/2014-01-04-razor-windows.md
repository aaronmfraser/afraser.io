---
layout: post
title: Razor and Windows
description: "Provisioning Windows with BMaaS"
modified: 2013-05-31
category: posts
tags: [windows,maas,razor,iaas,puppetlabs]
share: false
image:
  feature: servers.jpg
  credit: wikimedia.org
  creditlink: http://wikimedia.org
---

<section id="table-of-contents" class="toc">
  <header>
    <h3 >Contents</h3>
  </header>
<div id="drawer" markdown="1">
*  Auto generated table of contents
{:toc}
</div>
</section><!-- /#table-of-contents -->



Working at an employer with diverse technological needs requires that what ever tools we use be incrediably versatile and secure. Recent development in [Puppetlabs Razor](https://github.com/puppetlabs/razor-server) has made it a viable option. 

### Requirements:

* Functional Razor-server install
* Access to MSDN or other Windows ISO and License Key
* Virtualization with host-only networking
* Windows server 2012 R2 VM
* Windows server 2008 R2 VM
* Vagrant (optional)

### Configure repo
Lets create a repo for our window server. This will create the razor repo-store directory and copy the contents of that iso into the intended directory. 
{% highlight text %}
RAZOR_ADMIN=http://localhost
razor create-repo --name=<repo-name> --iso-url=<url to iso>
{% endhighlight %}

#### Resolve DVD/libarchive bug
Razor uses libarchive to setup repos from an iso file. Due to the size of windows server ISOs, it can't open and copy the into the repo. 

To revolve this we have to mount the iso:

{% highlight text %}
mount -o loop /mnt/cdrom <iso file>
cp /mnt/cdrom/* <razor-repo-store>
{% endhighlight %}

### Build wim file
To start it would be a good idea to read puppetlabs writeup on installing windows: [windows instructions](https://github.com/puppetlabs/razor-server/wiki/Installing-windows)


#### Windows 2012 R2 Build
* Install [WinPE5](http://www.microsoft.com/en-us/download/details.aspx?id=39982) on your windows server. 
* Download the contents of build-winpe from razor-server repo into a build directory on the windows server. 
* Run the build script: 

{% highlight text %}
powershell -executionpolicy bypass -noninteractive -file build-razor-winpe.ps1
{% endhighlight %}

The build script mounts the wim provided with the ADK. We need to copy a file out of there, bootmgr.exe. We'll cover the why later. While the build process is  executing, open the build directory you made and head into the razor-wim-mount directory. The path in the mount point is `Windows\Boot\PXE\bootmgr.exe`. Copy the file out of the mount as it will need to be placed on the razor repo directory. I found this little trick [here](http://blog.devicenull.org/2013/11/14/ipxe-wimboot-and-windows-server-2012r2.html)

Once the build process is completed please copy the wim and the copied bootmgr.exe file to razor. 
 
#### Windows 2008 R2 Build
Puppet build scripts are dependent on DISM cmdlets.

##### Build Steps:
* Install windows updates:
	* [WinPE4](http://www.microsoft.com/en-us/download/details.aspx?id=30652) 
	* [Microsoft .NET Framework 4.5](http://www.microsoft.com/en-us/download/details.aspx?id=30653)
    * [Windows Management Framework 4.0](http://www.microsoft.com/en-us/download/details.aspx?id=40855)
* Download the contents of build-winpe from razor-server repo into a build directory on the windows server. 
* As this is not Windows 8/2012, the DISM cmdlets arent automatically imported. To do so modify the build-razor-winpe.ps1 script:

{% highlight text %}
import-module dism` -> `import-module "C:\Program Files (x86)\Windows Kit\8.0\Assessment and Deployment Kit\Deployment Tools\amd64\DISM"
{% endhighlight %}

* Run the build script:

{% highlight text %}
powershell -executionpolicy bypass -noninteractive -file build-razor-winpe.ps1
{% endhighlight %}

Dont worry about the bootmgr.exe this time, the one copied from 2012 will work here as well. Once the build completes, copy the new winpe.wim to your razor repo for windows 2008 R2. 

### Configure Recipe
I found that the behaviour in of templating in the recipes to not work as directed. So please copy the windows dir and the windows.yaml and make a copy for each new version of the OS. You will them need to adjust the the boot_wim.erb in each of the recipe directories. 

#### Windows 2012 R2
Change from BOOTMGR to bootmgr.exe

{% highlight text %}
initrd ${base}/bootmgr.exe			bootmgr.exe
{% endhighlight %}

#### Windows 2008 R2
Remove the additional fonts from the boot_wim.erb

{% highlight text %}
initrd ${base}/boot/fonts/segmono_boot.ttf	segmono_boot.ttf
initrd ${base}/boot/fonts/segoe_slboot.ttf	segoe_slboot.ttf
initrd ${base}/boot/fonts/wgl4_boot.ttf		wgl4_boot.ttf
{% endhighlight %}

### unattended.xml
You should remove the contents of the current unattended.xml files in 8-pro. This file will not work with Windows Server 2008 R2 nor 2012 R2. It would be best to look over Microsofts documentation process on how to construct an unattended.xml. 

### Test
Now all you need to do is configure a policy to use the your new repo and kickstart a windows vm. 

