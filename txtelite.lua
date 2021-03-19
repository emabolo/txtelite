--[[

/* txtelite.c  1.5 */
/* Textual version of Elite trading (C implementation) */
/* Converted by Ian Bell from 6502 Elite sources.
   Original 6502 Elite by Ian Bell & David Braben.
   Edited by Richard Carlsson to compile cleanly under gcc
   and to fix a bug in the goat soup algorithm.
 */

/* ----------------------------------------------------------------------
  The nature of basic mechanisms used to generate the Elite socio-economic
universe are now widely known. A competant games programmer should be able to
produce equivalent functionality. A competant hacker should be able to lift 
the exact system from the object code base of official conversions.

  This file may be regarded as defining the Classic Elite universe.

  It contains a C implementation of the precise 6502 algorithms used in the
 original BBC Micro version of Acornsoft Elite together with a parsed textual
 command testbed.

  Note that this is not the universe of David Braben's 'Frontier' series.


ICGB 13/10/99
iancgbell@email.com
www.ibell.co.uk
  ---------------------------------------------------------------------- */

Note that this program is "quick-hack" text parser-driven version
of Elite with no combat or missions.

------------------------------------------------------------------------
 Ported to LUA by Emanuele Bolognesi.

 Since the code uses bitwise operators, LUA5.3+ is required

--]]

tonnes=0
maxlen=20

-- int boolean;
-- unsigned char uint8;
-- unsigned short uint16;
-- signed short int16;
-- signed long int32;

-- uint16 myuint;
uint ='uint_is_forbidden'

--typedef int planetnum;
--typedef struct{ uint8 a,b,c,d;} fastseedtype;  /* four byte random number used for planet description */
--typedef struct
--{ uint16 w0; uint16 w1; uint16 w2;} seedtype;  /* six byte random number used as seed for planets */

-- typedef struct
-- {	 myuint x;
   -- myuint y;       /* One byte unsigned */
   -- myuint economy; /* These two are actually only 0-7  */
   -- myuint govtype;   
   -- myuint techlev; /* 0-16 i think */
   -- myuint population;   /* One byte */
   -- myuint productivity; /* Two byte */
   -- myuint radius; /* Two byte (not used by game at all) */
	-- fastseedtype	goatsoupseed;
   -- char name[12];
-- } plansys ;


galsize=256
AlienItems=17	-- increased to 17 since arrays start at 1 in lua
lasttrade=17	-- index of last elemement of goods array

numforLave=8       --/* Lave is 7th generated planet in galaxy one */
numforZaonce=129
numforDiso =147
numforRied =46

galaxy = {}
for i=1,galsize do
	galaxy[i] = {}
end


MainSeed = {}
rnd_seed = {}

-- typedef struct
-- {	myuint quantity[lasttrade+1];
  -- myuint price[lasttrade+1];
-- } markettype ;

--/* Player workspace */
shipshold = {}  --/* Contents of cargo bay */
for i=1,AlienItems do
	shipshold[i] = 0
end

localmarket = {}
localmarket.price = {}
localmarket.quantity = {}

holdspace = 0

fuelcost =2 --/* 0.2 CR/Light year */
maxfuel =70 --/* 7.0 LY tank */

base0=0x5A4A
base1=0x0248
base2=0xB753 -- /* Base seed for galaxy 1 */

-- changed to UPPERCASE
pairsString = "ABOUSEITILETSTONLONUTHNO".."..LEXEGEZACEBISO".."USESARMAINDIREA.".."ERATENBERALAVETI".."EDORQUANTEISRION"

govnames={"Anarchy","Feudal","Multi-gov","Dictatorship","Communist","Confederacy","Democracy","Corporate State"}

econnames={"Rich Ind","Average Ind","Poor Ind","Mainly Ind","Mainly Agri","Rich Agri","Average Agri","Poor Agri"}

unitnames={"t","kg","g"};

--/* Data for DB's price/availability generation system */
--/*                   Base  Grad Base Mask Un   Name
 --                    price ient quant     it              */ 

POLITICALLY_CORRECT	= 0
commodities = {}

-- typedef struct
-- {                       --  /* In 6502 version these were: */
   -- myuint baseprice;    --  /* one byte */
   -- int16 gradient;		--  /* five bits plus sign */
   -- myuint basequant;    --  /* one byte */
   -- myuint maskbyte;     --  /* one byte */
   -- myuint units;        --  /* two bits */
   -- char   name[20];     --  /* longest="Radioactives" */
  -- } tradegood ;

Commodities_values={
                    {0x13,-0x02,0x06,0x01,0,"Food        "},
                    {0x14,-0x01,0x0A,0x03,0,"Textiles    "},
                    {0x41,-0x03,0x02,0x07,0,"Radioactives"},
                    {0x28,-0x05,0xE2,0x1F,0,"Slaves      "},
                    {0x53,-0x05,0xFB,0x0F,0,"Liquor/Wines"},
                    {0xC4,0x08,0x36,0x03,0,"Luxuries    "},
                    {0xEB,0x1D,0x08,0x78,0,"Narcotics   "},
                    {0x9A,0x0E,0x38,0x03,0,"Computers   "},
                    {0x75,0x06,0x28,0x07,0,"Machinery   "},
                    {0x4E,0x01,0x11,0x1F,0,"Alloys      "},
                    {0x7C,0x0d,0x1D,0x07,0,"Firearms    "},
                    {0xB0,-0x09,0xDC,0x3F,0,"Furs        "},
                    {0x20,-0x01,0x35,0x03,0,"Minerals    "},
                    {0x61,-0x01,0x42,0x07,1,"Gold        "},
                    {0xAB,-0x02,0x37,0x1F,1,"Platinum    "},
                    {0x2D,-0x01,0xFA,0x0F,2,"Gem-Strones "},
                    {0x35,0x0F,0xC0,0x07,0,"Alien Items "}
}
tradegood_struct = {'baseprice','gradient','basequant','maskbyte','units','name'}

for ci,struct in ipairs(Commodities_values) do
	commodities[ci] = {}
	for i,value in ipairs(struct) do
		key = tradegood_struct[i]
		-- print("i="..ci..", field="..key.."="..value)
		commodities[ci][key] = value
	end
end

desc_list = {}
for i=1,36 do
	desc_list[i] = {}     -- create a new row
	for j=1,5 do
		desc_list[i][j] = ''
	end
end

desc_list = {
{"fabled", "notable", "well known", "famous", "noted"},	--81
{"very", "mildly", "most", "reasonably", ""},	-- 82
{"ancient", "\x95", "great", "vast", "pink"},
{"\x9E \x9D plantations", "mountains", "\x9C", "\x94 forests", "oceans"},
{"shyness", "silliness", "mating traditions", "loathing of \x86", "love for \x86"},
{"food blenders", "tourists", "poetry", "discos", "\x8E"},
{"talking tree", "crab", "bat", "lobst", "\xB2"},
{"beset", "plagued", "ravaged", "cursed", "scourged"},
{"\x96 civil war", "\x9B \x98 \x99s", "a \x9B disease", "\x96 earthquakes", "\x96 solar activity"},	--89
{"its \x83 \x84", "the \xB1 \x98 \x99","its inhabitants' \x9A \x85", "\xA1", "its \x8D \x8E"},	--8A
{"juice", "brandy", "water", "brew", "gargle blasters"},
{"\xB2", "\xB1 \x99", "\xB1 \xB2", "\xB1 \x9B", "\x9B \xB2"},
{"fabulous", "exotic", "hoopy", "unusual", "exciting"},
{"cuisine", "night life", "casinos", "sit coms", " \xA1 "},
{"\xB0", "The planet \xB0", "The world \xB0", "This planet", "This world"},	--8F
{"n unremarkable", " boring", " dull", " tedious", " revolting"},	--90
{"planet", "world", "place", "little planet", "dump"},
{"wasp", "moth", "grub", "ant", "\xB2"},
{"poet", "arts graduate", "yak", "snail", "slug"},
{"tropical", "dense", "rain", "impenetrable", "exuberant"},
{"funny", "wierd", "unusual", "strange", "peculiar"},
{"frequent", "occasional", "unpredictable", "dreadful", "deadly"},
{"\x82 \x81 for \x8A", "\x82 \x81 for \x8A and \x8A", "\x88 by \x89", "\x82 \x81 for \x8A but \x88 by \x89","a\x90 \x91"},
{"\x9B", "mountain", "edible", "tree", "spotted"},
{"\x9F", "\xA0", "\x87oid", "\x93", "\x92"},
{"ancient", "exceptional", "eccentric", "ingrained", "\x95"},	-- 9A
{"killer", "deadly", "evil", "lethal", "vicious"},
{"parking meters", "dust clouds", "ice bergs", "rock formations", "volcanoes"},
{"plant", "tulip", "banana", "corn", "\xB2weed"},
{"\xB2", "\xB1 \xB2", "\xB1 \x9B", "inhabitant", "\xB1 \xB2"},
{"shrew", "beast", "bison", "snake", "wolf"},
{"leopard", "cat", "monkey", "goat", "fish"},	-- A0
{"\x8C \x8B", "\xB1 \x9F \xA2","its \x8D \xA0 \xA2", "\xA3 \xA4", "\x8C \x8B"},
{"meat", "cutlet", "steak", "burgers", "soup"},
{"ice", "mud", "Zero-G", "vacuum", "\xB1 ultra"},
{"hockey", "cricket", "karate", "polo", "tennis"}
}


--/**-Required data for text interface **/

tradnames = {} --/* Tradegood names used in text commands Set using commodities array */
nocomms = 14

local dobuy = ""
local dosell= ""
local dofuel= ""
local dojump= ""
local docash= ""
local domkt= ""
local dohelp= ""
local dohold= ""
local dosneak= ""
local dolocal= ""
local doinfo= ""
local dogalhyp= ""
local doquit= ""
local dotweakrand= ""

commands={"buy","sell","fuel","jump","cash","mkt","help","hold","sneak","local","info","galhyp","quit","rand"}

nativerand = 1
currentplanet = 0      --/* Current planet */
galaxynum = 1          --/* Galaxy number (1-8) */
cash = 0
fuel = 0

local lastrand = 0;


--/**- General functions **/
-----------------------------------------------------
function onebyte(num)
	return num&0xFF
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

------------------------------------------------------
function mysrand(seed)
	math.randomseed(seed)
	lastrand = seed - 1
end

function myrand()
	local r
	if nativerand>0 then r=math.random(2147483648)-1
	else
	--	// As supplied by D McDonnell	from SAS Institute C
		r = (((((((((((lastrand << 3) - lastrand) << 3) + lastrand) << 1) + lastrand) << 4) - lastrand) << 1) - lastrand) + 0xe60) & 0x7fffffff
		lastrand = r - 1;	
	end
	return r
end

function randbyte()
	local rand_byte = myrand()&0xFF
	return rand_byte
end

function mymin(a,b)
	return math.min(a,b)
end

function stop(message)
	print(message)
	os.exit()
end

-- /**+  ftoi **/
function ftoi(value)
	return math.floor(value+0.5);
end

-- /**+  ftoi2 **/
function ftoi2(value)
	return math.floor(value);
end

function tweakseed()
  local temp = MainSeed.w0+MainSeed.w1+MainSeed.w2	-- /* 2 byte aritmetic */
  MainSeed.w0 = MainSeed.w1
  MainSeed.w1 = MainSeed.w2
  MainSeed.w2 = temp
end

--/**-String functions for text interface **/

function stripout(s,c) --/* Remove all c's from string s */
	s = string.gsub(s, c, '')
	return s
end

function stringbeg(s,t)
--/* Return nonzero iff string t begins with non-empty string s */
	if string.find(string.lower(t),string.lower(s)) == 1 then return true
	else return false
	end
end

function stringmatch(s,a,n)
--/* Check string s against n options in string array a
--   If matches ith element return i+1 else return 0 */
	local i=1
	while i<=n do
		if string.find(string.lower(a[i]),string.lower(s)) == nil then i=i+1
		else return i
		end
	end
	return 0
end

function spacesplit(s)
--/* Split string s at first space, returning first 'word' in t & shortening s
-- Buy/sell commands are like this: BUY Food 2 (amount is the second word -> shortened)

	local i,j=1,1
	local l = string.len(s)
	local firstword = ''
	local shortened = ''

	-- remove initial spaces
    while i<=l and string.sub(s,i,i)==' ' do
		i=i+1
	end
    if i>l then
		return '',''
	end
	
    while i<=l and string.sub(s,i,i)~=' ' do
		firstword = firstword .. string.sub(s,i,i)
		i = i+1
	end
    i = i+1
    while i<=l do
		shortened = shortened .. string.sub(s,i,i)
		i = i+1
	end
	return firstword,shortened
end

--/**-Functions for stock market **/

function gamebuy(i,a)
 --/* Try to buy amount a of good i  Return amount bought */
 --/* Cannot buy more than is availble, can afford, or will fit in hold */
	local t = 0
    if cash<=0 or a == nil then t=0
    else
		t=mymin(localmarket.quantity[i],a)
    	if commodities[i].units==tonnes then t = mymin(holdspace,t) end
    	t = mymin(t, math.floor(cash/(localmarket.price[i])))
    end
	shipshold[i] = shipshold[i]+t
    localmarket.quantity[i] = localmarket.quantity[i] -t
    cash = cash - t*localmarket.price[i]
    if commodities[i].units==tonnes then holdspace = holdspace-t end
	return t
end

function gamesell(i,a) --/* As gamebuy but selling */
	if a == nil then return 0 end
	local t=mymin(shipshold[i],a)
	shipshold[i] = shipshold[i]-t;
    localmarket.quantity[i] = localmarket.quantity[i] +t
    if commodities[i].units==tonnes then holdspace = holdspace+t end
    cash = cash + t*localmarket.price[i]
    return t
end

function genmarket(fluct,p)
--/* Prices and availabilities are influenced by the planet's economy type
--   (0-7) and a random "fluctuation" byte that was kept within the saved
--   commander position to keep the market prices constant over gamesaves.
--   Availabilities must be saved with the game since the player alters them
--   by buying (and selling(?))

--   Almost all operations are one byte only and overflow "errors" are
--   extremely frequent and exploited.

--   Trade Item prices are held internally in a single byte=true value/4.
--   The decimal point in prices is introduced only when printing them.
--   Internally, all prices are integers.
--   The player's cash is held in four bytes. 
-- */

	local market ={}
	market.quantity = {}
	market.price = {}
	
	for i=1,lasttrade do
		local product = math.floor((p.economy)*(commodities[i].gradient))
		local changing = math.floor(fluct & (commodities[i].maskbyte))
		local q =  math.floor((commodities[i].basequant) + changing - product)
		q = q&0xFF
		if q&0x80 >0 then q=0 end			--/* Clip to positive 8-bit */    In LUA I had to add "> 0"
		market.quantity[i] = q & 0x3F	--/* Mask to 6 bits */
		q =  (commodities[i].baseprice) + changing + product
		q = q & 0xFF
		market.price[i] = q*4
	end
	market.quantity[AlienItems] = 0	-- /* Override to force nonavailability */
	return market
end

function displaymarket(m)
	for i=1,lasttrade do
		print()
		io.write(string.format("%s",commodities[i].name))
		io.write(string.format("\t%.1f",m.price[i]/10))
		io.write(string.format("\t%u",m.quantity[i]))
		io.write(string.format("%s",unitnames[commodities[i].units+1]))
		io.write(string.format("\t%u",shipshold[i]))
	end
end

--/**-Generate system info from seed **/

function makesystem()
	local thissys = {}
	local longnameflag=(MainSeed.w0)&64
	local pairs1 = string.sub(pairsString,25)				-- /* start of pairsString used by this routine */
	
	thissys.x = onebyte(MainSeed.w1 >>8)					-- In LUA I need to cut this to one byte
	thissys.y = onebyte(MainSeed.w0 >>8)
	
	if thissys.x > 255 then
		stop("error level x="..thissys.x)
	end
	if thissys.y > 255 then
		stop("error level y="..thissys.y)
	end

	thissys.govtype =(MainSeed.w1>>3)&7	-- /* bits 3,4 &5 of w1 */
	thissys.economy =(MainSeed.w0>>8)&7	-- /* bits 8,9 &A of w0 */

	if thissys.govtype <=1 then
		thissys.economy = thissys.economy|2
	end

	-- ^ in C is the bitwise XOR
	thissys.techlev =((MainSeed.w1>>8)&3)+(thissys.economy~7)
	thissys.techlev = thissys.techlev + (thissys.govtype>>1)
	
	if thissys.techlev > 16 then
		stop("error level tech="..thissys.techlev)
	end
	
	if thissys.govtype&1 ==1 then thissys.techlev = thissys.techlev +1 end
	
	--   /* C simulation of 6502's LSR then ADC */
 
	thissys.population = 4*thissys.techlev + thissys.economy
	thissys.population = thissys.population + thissys.govtype + 1
	
	if thissys.population > 255 then
		stop("error level population="..thissys.population)
	end

	thissys.productivity = ((thissys.economy~7)+3)*(thissys.govtype+4)
	thissys.productivity = thissys.productivity * thissys.population*8
	
	if thissys.productivity > 65535 then
		stop("error level productivity="..thissys.productivity)
	end

	--thissys.radius = 256*(((MainSeed.w2>>8)&15)+11) + thissys.x
	
	thissys.goatsoupseed = {}

	thissys.goatsoupseed.a = onebyte(MainSeed.w1)
	thissys.goatsoupseed.b = onebyte(MainSeed.w1 >>8)
	thissys.goatsoupseed.c = onebyte(MainSeed.w2)
	thissys.goatsoupseed.d = onebyte(MainSeed.w2 >>8)

	local pair1=2*((MainSeed.w2>>8)&31)
	tweakseed()
	local pair2=2*((MainSeed.w2>>8)&31)
	tweakseed()
	local pair3=2*((MainSeed.w2>>8)&31)
	tweakseed()
	local pair4=2*((MainSeed.w2>>8)&31)
	tweakseed()
  
  -- /* Always four iterations of random number */
	pair1 = pair1+1	-- to be used with LUA string.sub
	pair2 = pair2+1
	pair3 = pair3+1
	pair4 = pair4+1

	-- TO BE IMPROVED
	thissys.name = string.sub(pairs1,pair1,pair1)
	
	thissys.name = thissys.name .. string.sub(pairs1,pair1+1,pair1+1)
	thissys.name = thissys.name .. string.sub(pairs1,pair2,pair2)
	thissys.name = thissys.name .. string.sub(pairs1,pair2+1,pair2+1)
	thissys.name = thissys.name .. string.sub(pairs1,pair3,pair3)
	thissys.name = thissys.name .. string.sub(pairs1,pair3+1,pair3+1)
	
	if longnameflag>0 then	-- /* bit 6 of ORIGINAL w0 flags a four-pair name */
		thissys.name = thissys.name ..string.sub(pairs1,pair4,pair4)
		thissys.name = thissys.name ..string.sub(pairs1,pair4+1,pair4+1)
	end
	thissys.name = string.gsub(thissys.name, "%.", "")
	return thissys
end


-- /**+Generate galaxy **/


--/* Functions for galactic hyperspace */

function rotatel(xnumber)	-- /* rotate 8 bit number leftwards */
--/* (tried to use chars but too much effort persuading this braindead language to do bit operations on bytes!) */
	local temp = xnumber&128
	return (2*(xnumber&127))+(temp>>7)
end

function twist(xnumber)
	return (256*rotatel(xnumber>>8))+rotatel(xnumber&255)
end

function nextgalaxy() 					-- /* Apply to base seed; once for galaxy 2  */
	MainSeed.w0 = twist(MainSeed.w0)	-- /* twice for galaxy 3, etc. */
	MainSeed.w1 = twist(MainSeed.w1)	-- /* Eighth application gives galaxy 1 again*/
	MainSeed.w2 = twist(MainSeed.w2)
end

--/* Original game generated from scratch each time info needed */
function buildgalaxy(galaxynum)
	MainSeed.w0=base0
	MainSeed.w1=base1
	MainSeed.w2=base2	-- /* Initialise seed for galaxy 1 */
	
	-- does not do anything if galaxynum is 1
	for galcount=1,galaxynum-1 do
		nextgalaxy()
	end
	-- /* Put galaxy data into array of structures */  
	for syscount=1,galsize do
		galaxy[syscount]=makesystem()
	end
end

function gamejump(i)	-- /* Move to system i */
	currentplanet=i
	localmarket = genmarket(randbyte(),galaxy[i])
end


function distance(a,b)
--/* separation between two planets (4*sqrt(X*X+Y*Y/4)) */
	return ftoi(4*math.sqrt((a.x-b.x)*(a.x-b.x)+(a.y-b.y)*(a.y-b.y)/4))
end


function matchsys(s)
	--/* Return id of the planet whose name matches passed strinmg closest to currentplanet - if none return currentplanet */
	local p=currentplanet;
	local d=9999;
	for syscount=1,galsize do
		if stringbeg(s,galaxy[syscount].name) then
			if distance(galaxy[syscount],galaxy[currentplanet])<d then
				d=distance(galaxy[syscount],galaxy[currentplanet])
				p=syscount
			end
		end
	end
	return p
end

-- /**-Print data for given system **/
function prisys(plsy,compressed)
	if compressed then
		io.write(string.format("%10s",plsy.name))
		io.write(string.format(" TL: %2i ",(plsy.techlev)+1))
		io.write(string.format("%12s",econnames[plsy.economy+1]))
		io.write(string.format(" %15s",govnames[plsy.govtype+1]))
	else
		io.write(string.format("\n\nSystem     : "))
		io.write(string.format("%s",plsy.name))
		io.write(string.format("\nPosition   : %i,",plsy.x))
		io.write(string.format("%i",plsy.y))
		io.write(string.format("\nEconomy    : "))
		io.write(string.format("%s (%i)",econnames[plsy.economy+1],plsy.economy))
		io.write(string.format("\nGovernment : "))
		io.write(string.format("%s (%i)",govnames[plsy.govtype+1],plsy.govtype))
		io.write(string.format("\nTech Level : %2i",(plsy.techlev)+1))
		io.write(string.format("\nTurnover   : %u",(plsy.productivity)))
		--print(string.format("\nRadius: %u",plsy.radius);
		-- /* fixed (R.C.): divide population by 10, not by 8, and format as float with 1 decimal */
		io.write(string.format("\nPopulation : %.1f Billion",(plsy.population) / 10.0))
	
		rnd_seed = plsy.goatsoupseed;
		print()
		goat_soup("\x8F is \x97.",plsy);
	end
end


--/**-Various command functions **/

function dotweakrand()
	nativerand = nativerand ~ 1
	return true
end

function dolocal(maxdistance)
	if maxdistance == nil then maxdistance = maxfuel end
	print("Galaxy number "..galaxynum)
	for syscount=1,galsize do
		local d=distance(galaxy[syscount],galaxy[currentplanet])
   		if d<=maxfuel then
    	 	if d<=fuel then
				io.write("\n * ");
			else
				io.write("\n - ");
			end
    		prisys(galaxy[syscount],true);
      		io.write(string.format(" (%.1f LY)",d/10))
    	end
	end
end

function doshowgalaxy()
	dolocal(10000)
end


function dojump(s) --/* Jump to planet name s */
	local dest=matchsys(s)
	if dest==currentplanet then
		print("\nBad jump")
		return false
	end
	local d=distance(galaxy[dest],galaxy[currentplanet])
	if d>fuel then
		print("\nJump too far")
		return false
	end
	fuel = fuel - d
	gamejump(dest)
	prisys(galaxy[currentplanet],false)
	return true
end

function dosneak(s) --/* As dojump but no fuel cost */
	local fuelkeep=fuel
	fuel=666
	local b=dojump(s)
	fuel=fuelkeep
	return b
end

function dogalhyp(s) --/* Jump to next galaxy */
                     --/* Preserve planetnum (eg. if leave 7th planet arrive at 7th planet) */
  galaxynum = galaxynum +1
  if galaxynum==9 then galaxynum=1 end
  buildgalaxy(galaxynum)
  print("Jumped to galaxy #"..galaxynum)
  return true
end

function doinfo(s)	-- /* Info on planet */
	local dest=matchsys(s)
	prisys(galaxy[dest],false)
	return true
end


function dohold(s)
	local a=tonumber(s)

	if a == nil then
		print("\nYou must specify the new hold capacity")
		return false
	end
	if a == 0 then
		print("\nHold capacity must be at least 1")
		return false
	end

	local t=0

	for i=1,lasttrade do
		if commodities[i].units==tonnes then t=t+shipshold[i] end
	end
	
	if t>a then 
		print("\nHold too small for your current goods")
		return false
	end
	holdspace=a-t
	return true
end

function dosell(s)	-- /* Sell amount S(2) of good S(1) eg. "Food 5" */
	local goods,amount = spacesplit(s)
	amount = tonumber(amount)
	if amount==nil then amount=1 end
	if amount <=0 then 
		amount=1
	end
	local i=stringmatch(goods,tradnames,lasttrade)	-- can be a smarter function
	if i==0 then
		print("\nUnknown trade good")
		return false
	end 
 
	local qt=gamesell(i,amount)
	
	if qt == 0 then
		io.write("Cannot sell any ")
	else
		io.write(string.format("\nSelling %i",qt))
    	io.write(string.format("%s",unitnames[commodities[i].units+1]))
    	io.write(" of ")
	end
    io.write(string.format("%s",tradnames[i]))
    return true
end

   
function dobuy(s) -- /* Buy amount S(2) of good S(1) eg. "Food 5" */
	local goods,amount = spacesplit(s)
	amount = tonumber(amount)
	if amount==nil then amount=1 end
	if amount <=0 then 
		amount=1
	end
	local i=stringmatch(goods,tradnames,lasttrade)	-- can be a smarter function
	if i==0 then
		print("\nUnknown trade good")
		return false
	end 

	local qt=gamebuy(i,amount)
	
	if qt == 0 then
		io.write("Cannot buy any ")
	else
		io.write(string.format("\nBuying %i",qt))
    	io.write(string.format("%s",unitnames[commodities[i].units+1]))
    	io.write(" of ")
	end
    io.write(string.format("%s",tradnames[i]))
    return true
end

function gamefuel(f) -- /* Attempt to buy f tonnes of fuel */
	if f+fuel>maxfuel then f=maxfuel-fuel end
	if fuelcost>0 then
		if f*fuelcost>cash then f= math.floor(cash/fuelcost) end
	end
	fuel = fuel + f
	cash = cash - fuelcost*f
	return f
end


function dofuel(s) --/* Buy amount S of fuel */
	if s == '' or s == nil then
		print("\nPlease enter an amount")
		return false
	end
	local f=gamefuel(math.floor(10*tonumber(s)))
	if f==0 then
		print("\nCan't buy any fuel")
	else
		io.write(string.format("\nBuying %.1fLY fuel",f/10))
	end
	return true
end

function docash(s) -- /* Cheat alter cash by S */
	if s == '' then
		print("Please the amount of money you want to add to the cash")
		return false
	end
	if tonumber(s)>0 then
		local a=math.floor(10*tonumber(s))
		cash = cash + a
		return true
	end
	print("Number not understood")
	return false
end

function domkt() --/* Show stock market */
  displaymarket(localmarket);
  io.write(string.format("\n\nFuel :%.1f",fuel/10))
  io.write(string.format("      Holdspace :%it",holdspace))
  return true
end

function donothing()
	return true
end

function doquit()
	print("Goodbye!")
	os.exit()
end

function dohelp()
   print("Commands are:");
   print("Buy   tradegood amount   (buy good)");
   print("Sell  tradegood amount   (sell good)");
   print("Fuel  amount             (buy amount LY of fuel)");
   print("Jump  planetname         (limited by fuel)");
   print("Sneak planetname         (any distance - no fuel cost)");
   print("Galhyp                   (jumps to next galaxy)");
   print("Info  planetname         (prints info on system");
   print("Mkt                      (shows market prices)");
   print("Local                    (lists systems within 7 light years)");
   print("Cash number              (alters cash - cheating!)");
   print("Hold number              (change cargo capacity)");
   print("Quit                     (exit)");
   print("Help                     (display this text)");
   print("Rand                     (toggle RNG)");
   print("\nAbbreviations allowed eg. b fo 5 = Buy Food 5, m= Mkt");
return true;
end


function gen_rnd_number ()
	local x = (rnd_seed.a * 2) & 0xFF
	local a = x + rnd_seed.c
	if rnd_seed.a > 127 then a = a+1 end
	rnd_seed.a = a & 0xFF
	rnd_seed.c = x

	a = math.floor(a / 256)		--/* a = any carry left from above */
	x = rnd_seed.b
	a = a + x + rnd_seed.d
	a = a & 0xFF
	rnd_seed.b = a
	rnd_seed.d = x
	return a
end

--/* "Goat Soup" planetary description string code - adapted from Christian Pinder's reverse engineered sources. */
--/* B0 = <planet name>
--	 B1 = <planet name>ian
--	 B2 = <random name>


function goat_soup(sourcestring,psy)

	for pos=1,string.len(sourcestring) do
		local c = string.byte(string.sub(sourcestring,pos,pos))
		--print("\nc=",c)
		if c<0x80 then
			io.write(string.char(c))
		else
			if c <=0xA4 then
				local rnd = gen_rnd_number()
				local index = 1
				if rnd >= 0x33 then index = index+1 end
				if rnd >= 0x66 then index = index+1 end
				if rnd >= 0x99 then index = index+1 end
				if rnd >= 0xCC then index = index+1 end
				
				--print("goat_soup",c-0x81+1,index)
				--print("string=",desc_list[c-0x81+1][index])
				goat_soup(desc_list[c-0x81+1][index],psy)

			elseif c == 0xB0 then 						-- /* planet name */
				io.write(string.sub(psy.name,1,1))
				io.write(string.lower(string.sub(psy.name,2)))
			elseif c == 0xB1 then
				io.write(string.sub(psy.name,1,1))		--: /* <planet name>ian */
				if string.sub(psy.name,-1) == 'E' or string.sub(psy.name,-1) == 'I' then
					io.write(string.lower(string.sub(psy.name,2,string.len(psy.name)-1)))
				else
					io.write(string.lower(psy.name))
				end
				io.write("ian")							-- TEMPORARY ---  need to understand what is it
			elseif c == 0xB2 then 						-- : /* random name */
				local len = gen_rnd_number() & 3
				for i=0,len do
					local x = gen_rnd_number() & 0x3e
					--/* fixed (R.C.): transform chars to lowercase unless first char of first pair, or second char of first
					--   pair when first char was not printed */
					local p1 = string.sub(pairsString,x,x)
					local p2 = string.sub(pairsString,x+1,x+1)
					if p1 ~= '.' then
						if i>0 then p1 = string.lower(p1) end
						io.write(p1)
					end
					if p2 ~= '.' then
						if i>0 or p1 ~= '.' then p2 = string.lower(p2) end
						io.write(p2)
					end
				end
			else 
				io.write(string.format("<bad char in data [%X]>",c))
			end
		end
	end
end

function parser(s) --/* Obey command s */
	local cmd,restofstring = spacesplit(s)
	local i=stringmatch(cmd,commands,nocomms)
	
	local exec_command = donothing
	local comfuncs ={dobuy,dosell,dofuel,dojump,docash,domkt,dohelp,dohold,dosneak,dolocal,doinfo,dogalhyp,doquit,dotweakrand}

	if i>0 then
		exec_command = comfuncs[i]
		return exec_command(restofstring)
	else
		io.write(string.format("\n Bad command (%s)",cmd))
		return false
	end
end


-- ================================================================================
-- ** main ** 
-- ================================================================================

print("\nWelcome to Text Elite 1.5.\n")

for i=1,lasttrade do
	tradnames[i] = commodities[i].name
end

mysrand(12345) -- /* Ensure repeatability */

buildgalaxy(galaxynum)

currentplanet = numforLave							-- /* Don't use jump */
localmarket = genmarket(0x00,galaxy[currentplanet])	-- /* Since want seed=0 */


fuel=maxfuel;
   
--#define PARSER(S) { char buf[0x10];strcpy(buf,S);parser(buf);}   

parser("hold 20")	--        /* Small cargo bay */
parser("cash +100")	--       /* 100 CR */
parser("help")

--#undef PARSER

while true do
	io.write(string.format("\n\nCash :%.1f>",cash/10))
	local getcommand = io.read()
    parser(getcommand)
end
 
--   /* 6502 Elite fires up at Lave with fluctuation=00
--      and these prices tally with the NES ones.
--      However, the availabilities reside in the saved game data.
--      Availabilities are calculated (and fluctuation randomised) on hyperspacing
--      I have checked with this code for Zaonce with fluctaution &AB 
--      against the SuperVision 6502 code and both prices and availabilities tally.
--   */


--/**+end **/

