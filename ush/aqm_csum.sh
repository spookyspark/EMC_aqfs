#! /bin/csh -f 

set echo
set temp_time = `date`
setenv ctime $temp_time[4]

# type csum -h for help

set exist_h = ` echo $argv | grep -e "-h" | wc -w `

if ($exist_h != 0) then
   goto usage
else
   goto checkarg
endif

cont:

set filetype = ncf

if (! -f $outfname) then
   setenv file_update N
else
   setenv file_update Y
endif

setenv vfile $vfname
setenv outfile $outfname

echo ' '

set system = `uname -a`
set mname = `uname -n | sed 's/\./ /g' ` 

#${HOMEaqm}/exec/aqm_csum
${EXECaqm}/aqm_csum

exit

#---------------------------------------------------------------------
checkarg:

set count = $#argv

#set default values
setenv surface N
setenv rm_last_step 0
setenv rm_first_step 0
setenv colsum N

setenv keep_last_step F
setenv keep_first_step F

if ($count > 0) then
   @ lc = 0

   while ($lc < $count[1])
     @ lc++

     if ("$argv[$lc]" == '-rl') then
        @ lc++
        setenv rm_last_step $argv[$lc]
     else if ("$argv[$lc]" == '-kl') then
        setenv keep_last_step T
     else if ("$argv[$lc]" == '-rf') then
        @ lc++
        setenv rm_first_step $argv[$lc]
     else if ("$argv[$lc]" == '-kf') then
        setenv keep_first_step T
     else if ("$argv[$lc]" == '-sl') then
        setenv surface Y
     else if ("$argv[$lc]" == '-cs') then
        setenv colsum Y
     else
        if (! `file $argv[$lc] | grep -i ascii | wc -l`) then
           goto misuage
        else 
           set vfname = $argv[$lc]
           @ lc++
        endif

        @ remaining = 1 + $count - $lc
        @ n = 1
        while ($n < $remaining)
          if ($n == 1) then
             echo $argv[$lc] > $DATA/__csum_file_$ctime
          else
             echo $argv[$lc] >> $DATA/__csum_file_$ctime
          endif
          @ n++
          @ lc++
        end

        @ n_dif_file = $remaining - 1
        set outfname = $argv[$lc]

     endif
   end
else
  goto misuage
endif

setenv n_formula `grep "=" $vfname  | wc -l`
setenv n_dif_file $n_dif_file

@ n = 0
while ($n < $n_dif_file)
  @ n++
  set loc_file = `head -n $n $DATA/__csum_file_$ctime | tail -n 1 | sed 's/f://' `
  ls -1 $loc_file* > $DATA/__csum_dir_$ctime
  set count = `wc -l $DATA/__csum_dir_$ctime`

  if ($n == 1) then
     setenv numfile $count[1]
  endif

  @ j = 0
  while ($j < $count[1])
    @ j++
    set fname = `printf "infile%2.2d_%3.3d\n" $n $j`
    setenv $fname `head -n $j $DATA/__csum_dir_$ctime | tail -n  1`
  end

  rm -f $DATA/__csum_dir_$ctime
end

goto cont

# -------------------------------------------------------------------------
usage:
echo ' '
echo ' csum [ -sl ] [ -rl n ] [ -rvl ] [ -rf n ] [ -rvf ] [ -cs ] '
echo '      [ -kf ] [ -kl ] '
echo '      variable_list input_file1 [ input_file2 ... ] outfile '
echo ' '
echo '  where -sl           -- process only surface layer'
echo '        -rl           -- remove last n time step data '
echo '        -rvl          -- remove the very last step (default not)'
echo '        -rf           -- remove first n time step data '
echo '        -rvf          -- remove the very first step (default not)'
echo '        -cs           -- compute column sum'
echo '        -kf           -- keep very first step among all in input files'
echo '                         (default not)'
echo '        -kl           -- keep very last step among all in input files'
echo '                         (default not)'
echo '        variable_list -- a list of variables, if variable is not'
echo '                         a aerosol variable, it will simply output'
echo '                         to the outfile without any computation'
echo ' '
echo '    Note: 1. file name can be a wild card prefix, e.g. if you have a '
echo '             series of files CCTM_CONC.20060801 CCTM_CONC.20060802 and so'
echo '             forth, file name will be CCTM_CONC'
echo '          2. If no outfile is supplied, the default name csum.ncf will'
echo '             be used'
echo '          3. format rules for variable_list file: '
echo '               -- new variable definition:'
echo '                    unit, new_variable_name = list_of_variable'
echo '                  number of blank space in between does not matter. A '
echo '                  comma is required to seperate unit with the new'
echo '                  variable name. The new variable definition can be '
echo '                  spanned in multiple lines.'
echo '               -- a block of expression is denoted by : and the entire'
echo '                  expression will be applied to the following variable'
echo '                  (if no operator followed, by default is multiplication)'
echo '               -- constant expression applies to the following block '
echo '                  expression only'
echo '               -- addition operation is by default'
echo '               -- a variable following by a comma and a number (no space'
echo '                  is allowed), that number indicates which file the'
echo '                  variable is coming from. If no number is attached, by '
echo '                  default, it is from file #1. If the number is 0, it'
echo '                  means it is defined in the same variable list file.'
echo '               -- if no unit is given (there should be at least one space'
echo '                  before the comma), it is consider an internal variable'
echo '                  which is treated as a regular variable in calculation'
echo '                  but it will not be output to a file'
echo '               -- there are two examples at /home/wdx/mytools/csum '
echo '                  example 2 shows how to use the internal variables '
echo '          4. option -rl is for consecutive multiple days CONC files since'
echo '             the last time step data of day x is the same as the first '
echo '             time step of day x+1'
echo '          5. setenv IOAPI_OFFSET_64 T to enable 64 bit offset netcdf file'
echo ' '
echo ' If you have any question, please contact David Wong, 541-3400'
echo ' '

exit

# -------------------------------------------------------------------------
misuage:

echo ' '
echo ' Syntax Error. Please type csum -h to see how to use csum'
echo ' '

exit
