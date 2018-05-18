Простой парсер для NMON файлов собранных с систем AIX. 

Для работы парсера сбор NMON должен осуществляться со следущими опциями `-y SCPU=on -y PCPU=on  -s 60 -ydays_file=1 -a 7 -yoverwrite=1 -o /var/nmon/ -T -V -P -M -N -^ -L -A -w 4 -l 150 -I 0.1 -d `  
Ссылка на парсер - [NMON parser](https://github.com/Ezjik-Sonic/NMON-pars)


Вывод данных по партициям, выводит потребление CPU,LPAR,MEM,Pbuf,DISKSERV

	Дата		Сериал	lparname	Entitled Used			User CPU			Paging Space			MEM Used			Pbuf for day		Disk Serv
	08OCT2017       1234567 lparname1      LPAR(6.69%/22.09%) 17:02:48     CPU(13.38%/44.2%) 17:02:48      PageSp(22.98MB/23MB) 16:53:48   MEM(25.02%/25.1%) 10:51:18      Pbuf(0 IO blocks)      DISKSERV: hdisk7(11.24 ms/41.8 ms) 03:00:41
	08OCT2017       1234567 lparname2      LPAR(29.73%/53.29%) 00:14:59    CPU(55.86%/59.6%) 07:35:03      PageSp(46.04MB/47MB) 06:20:02   MEM(80.29%/81.2%) 21:15:09      Pbuf(0 IO blocks)      DISKSERV:
	08OCT2017       1234567 lparname3      LPAR(29.73%/53.19%) 15:12:52    CPU(55.48%/60.8%) 15:09:52      PageSp(282.8MB/283MB) 16:52:53  MEM(47.8%/48.3%) 20:55:55       Pbuf(0 IO blocks)      DISKSERV:
	08OCT2017       1234568 lparname4      LPAR(2.46%/71.2%) x2 03:34:51   CPU(8.39%/79.9%) 03:30:50       PageSp(31.11MB/32MB) 21:41:35   MEM(37.47%/37.8%) 03:31:50      Pbuf(61 IO blocks)     DISKSERV:



Вывод данных по сети, количество ошибок зафиксированных на интерфейсе за сутки. 
-----
> Подробно тут [Network statistics](https://www.ibm.com/support/knowledgecenter/ssw_aix_72/com.ibm.aix.prftools/network_stat.htm)

	08OCT2017	1234567	lparname1	NETERROR: en0-ierrs(0 ms) lo0-ierrs(0 ms) en0-oerrs(0 ms) lo0-oerrs(0 ms) en0-collisions(0 ms) lo0-collisions(0 ms)
	08OCT2017	1234567	lparname2	NETERROR: en1-ierrs(0 ms) en0-ierrs(0 ms) lo0-ierrs(0 ms) en1-oerrs(0 ms) en0-oerrs(0 ms) lo0-oerrs(0 ms) en1-collisions(0 ms) en0-collisions(0 ms) lo0-collisions(0 ms)
	08OCT2017	1234567	lparname3	NETERROR: en0-ierrs(0 ms) lo0-ierrs(0 ms) en0-oerrs(0 ms) lo0-oerrs(0 ms) en0-collisions(0 ms) lo0-collisions(0 ms)
	08OCT2017	1234567	lparname4	NETERROR: en0-ierrs(0 ms) lo0-ierrs(0 ms) en0-oerrs(0 ms) lo0-oerrs(0 ms) en0-collisions(0 ms) lo0-collisions(0 ms)
	08OCT2017	1234568	lparname5	NETERROR: en1-ierrs(0 ms) lo0-ierrs(0 ms) en1-oerrs(0 ms) lo0-oerrs(0 ms) en1-collisions(0 ms) lo0-collisions(0 ms)


Вывод данных по FC. 
-----
Число запросов на чтение нас адаптер, число запросов на запись на адаптер, kb/s чтения на адаптер, kb/s запись на адаптер. [I/O statistics](https://www.ibm.com/support/knowledgecenter/ssw_aix_72/com.ibm.aix.prftools/io_stat.htm) 

	08OCT2017 1234567 lparname1	FCXFERIN(0.19 IOs/0.8 IOs) 23:55:27	FCXFEROUT(0.65 IOs/1.8 IOs) 23:55:27	FCREAD(24.13 KBs/51.7 KBs) 23:55:27	FCWRITE(2.81 KBs/22.1 KBs) 23:55:27	Pbuf(0 IO blocks)	Read/Write(0.89 %/99.11 %)

	08OCT2017 1234567 lparname2	FCXFERIN(5.82 IOs/257.9 IOs) 04:07:45	FCXFEROUT(16.1 IOs/37.9 IOs) 16:10:44	FCREAD(1837.06 KBs/39968.4 KBs) 17:02:48	FCWRITE(3050.36 KBs/4964.7 KBs) 17:08:49	Pbuf(0 IO blocks)	Read/Write(37.59 %/62.41 %)

	08OCT2017 1234567 lparname3	FCXFERIN(7.23 IOs/76.4 IOs) 19:41:08	FCXFEROUT(1.86 IOs/12.6 IOs) 05:01:01	FCREAD(107.16 KBs/685.9 KBs) 19:41:08	FCWRITE(22.66 KBs/596.0 KBs) 21:21:10	Pbuf(0 IO blocks)	Read/Write(82.55 %/17.45 %)

	08OCT2017 1234567 lparname4	FCXFERIN(5.79 IOs/184.5 IOs) 20:50:55	FCXFEROUT(2.22 IOs/47.8 IOs) 21:13:55	FCREAD(85.3 KBs/2815.1 KBs) 09:15:49	FCWRITE(47.14 KBs/1169.8 KBs) 21:14:55	Pbuf(0 IO blocks)	Read/Write(64.41 %/35.59 %)

	08OCT2017 1234568 lparname5	FCXFERIN(2.46 IOs/134.1 IOs) 04:02:53	FCXFEROUT(1.77 IOs/390.1 IOs) 07:01:09	(133.81 KBs/11752.4 KBs) 09:45:26	FCWRITE(106.34 KBs/19688.1 KBs) 02:01:44	Pbuf(61 IO blocks)	Read/Write(55.72 %/44.28 %)



Вывод данных по дисковой подсистеме, опции "-t disk  --zero".
-----
	16MAY2018 21A84C7 lparname
		FCREAD(1713.75 KBs/74926.5 KBs) FCWRITE(103.12 KBs/4236.4 KBs)  IOADAPT(637.47/74945.9) FCXFERIN(83.47 IOs/1267.2 IOs)  FCXFEROUT(11.57 IOs/104.8 IOs)
		Pbuf(0 IO blocks)       Read/Write(94.32 %/5.68 %)      FCTOTALGB(9.95 GB)      FCXFERTOTAL(545989.7 IO)
	IOADAPT:
		fcs0_read-KB/s(1712.76/74809.9) fcs0_write-KB/s(103.44/3864.4)  fcs0_xfer-tps(94.83/1280.3)
		fcs1_read-KB/s(1713.65/74707.9) fcs1_write-KB/s(103.76/4045.7)  fcs1_xfer-tps(94.84/1280.3)
		fcs2_read-KB/s(1714.26/74809.9) fcs2_write-KB/s(102.66/4237.4)  fcs2_xfer-tps(94.83/1282.4)
		fcs3_read-KB/s(1711.81/74945.9) fcs3_write-KB/s(103.11/3964.6)  fcs3_xfer-tps(94.83/1280.3)
	DISKBUSY:
		hdisk0(0.09 %/20.0 %)   hdisk3(0.1 %/3.6 %)     hdisk4(9.66 %/83.3 %)   hdisk5(2.53 %/80.5 %)
	DISKSERV:
		hdisk0(1.23 ms/106.7 ms)	hdisk3(1.02 ms/24.0 ms) hdisk4(0.58 ms/13.2 ms) hdisk5(0.76 ms/15.7 ms)
	DISKWAIT:
		hdisk0(0 ms)    hdisk3(0 ms)    hdisk4(0 ms)    hdisk5(0.05 ms/0.1 ms)
	DISKREAD:
		hdisk0(1566.83 KBs/15014.6 KBs) hdisk3(2.4 KBs/823.4 KBs)       hdisk4(5427.21 KBs/151734.5 KBs)       hdisk5(1284.11 KBs/146371.0 KBs)
	DISKWRITE:
		hdisk0(1.01 KBs/208.1 KBs)      hdisk3(6.36 KBs/552.2 KBs)      hdisk4(235.67 KBs/6840.4 KBs)   hdisk5(170.34 KBs/11722.0 KBs)




Вывод только выбранных метрик и индикаторв, опции " -t adv -dev PROC".
-----
	PROC:
		Runnable(0.21/1.40)     Swap-in(0.02/0.08)      asleep_bufio(0) asleep_diocio(0.5/1)
		asleep_rawio(0) exec(3.17/34)   fork(4.2/49)    msg(0)
		pswitch(2158.97/16213)  read(53/1022)   sem(0)  syscall(1128.66/11449)
		write(11.97/164)




Расшифровка:

> Подробную информацию смотреть по значениям всех метрик - [тут](https://www.ibm.com/support/knowledgecenter/ssw_aix_72/com.ibm.aix.prftools/nmon_tool.htm)

LPAR - Сумма метрик `VP_User%` и `VP_Sys%`

	LPAR - Records logical partition processor utilization statistics. This statistics is recorded only for the shared partitions. 
		VP_User%
		    Percentage of virtual CPU consumption in user mode.
		VP_Sys%
	    	Percentage of virtual CPU consumption in system mode.


CPU - Сумма метрик `User%` и `Sys%`

	CPU_ALL
	   Records the overall LPAR processor utilization based on the Processor Utilization Resource register (PURR) entries. This section is recorded by default. 
	User %
	    Average percentage of processor utilization as against the total processor utilization of the LPAR, when the LPAR is in user mode.
	System %
	    Average percentage of processor utilization as against the total processor utilization of the LPAR, when the LPAR is in kernel mode. This percentage includes donated PURR and stolen PURR values.>
	        Donated PURR is the number of processor cycles that are donated by the LPAR to any other LPAR.
	        Stolen PURR is the number of processor cycles that are used by the hypervisor from the LPAR.


MEM Used - сумма метрик `Free%` и `FScache%`

	MEMNEW - Provides new set of memory metrics. These details are recorded by default.
		FScache%
		    Percentage of real memory that is used by the file system cache as against the real memory. 
		Free%
		    Percentage of RAM available as against total RAM. 


Pbuf - pending disk I/Os blocked with no pbuf . Смотрит сколько было нехватки буферов за сутки.
> Подробнее тут [Blocked I/Os due to buffers shortage](http://www-01.ibm.com/support/docview.wss?uid=isg3T1025198)

Disk Serv - среднее за сутки метрики DISKSERV, (без учета покая)

	DISKSERV Disk Service Time msec/xfer
	    Average disk I/O service time per transfer in milliseconds.




 
