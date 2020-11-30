#!/bin/bash
#SBATCH --partition=day
#SBATCH --job-name=uszone
#SBATCH --ntasks=1 --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=2000
#SBATCH --time=10:00:00
#SBATCH -o job-%x-slurm-%j-%A_%a.out
#SBATCH --array=1-300

# some job information
mem_bytes=$(</sys/fs/cgroup/memory/slurm/uid_${SLURM_JOB_UID}/job_${SLURM_JOB_ID}/memory.limit_in_bytes)
mem_gbytes=$(( $mem_bytes / 1024 **3 ))

echo "Starting at $(date)"
echo "Job submitted to the ${SLURM_JOB_PARTITION} partition, the default partition on ${SLURM_CLUSTER_NAME}"
echo "Job name: ${SLURM_JOB_NAME}, Job ID: ${SLURM_JOB_ID}"
echo "  I have ${SLURM_CPUS_ON_NODE} CPUs and ${mem_gbytes}GiB of RAM on compute node $(hostname)"


### load the module
module load GRASS/7.8.0-foss-2018a-Python-3.6.4

### define resolution
export res=5min


### directory

export project_dir=/gpfs/loomis/project/planavsky/sz243

export grassdb_dir=$project_dir/Grass/grassdb_world

export out_dir=$project_dir/Grass/output/silicate_weathering_2020_10_22/US_zones_$res

# echo the current zone
echo this is zone z_$SLURM_ARRAY_TASK_ID
printf "\n\n"

export mapset_name=z_$SLURM_ARRAY_TASK_ID

echo this is mapset $mapset_name

# count time
SECONDS=0

# calculate begin and end
# very quick 5 minutes for 724 regions for 1 parameter. it might took 10 hours for all the parameters!

max_files=217152
step=724
num_start=$(( (SLURM_ARRAY_TASK_ID-1)*step + 1 ))

num_end=$(( SLURM_ARRAY_TASK_ID*step ))

if [ $num_end -gt $max_files  ] ; then  num_end=$max_files ; fi 

export num_start
export num_end

################ enter grass and calculate

grass78 -text -f $grassdb_dir/world_30sec/${mapset_name} <<'EOF'


region_us_n=($(awk -F, '{print $1}' region_us_${res}.csv))

region_us_e=($(awk -F, '{print $2}' region_us_${res}.csv))

region_us_s=($(awk -F, '{print $3}' region_us_${res}.csv))

region_us_w=($(awk -F, '{print $4}' region_us_${res}.csv))

# begin loop samples
for i in $(seq $num_start $num_end); do

	printf "\n\nnow is $i sample \n"

	# get the real index
	ind_i=$((i-1))

	# zoom to region
	g.region ${region_us_n[$ind_i]} ${region_us_e[$ind_i]} ${region_us_s[$ind_i]}  ${region_us_w[$ind_i]} res=0:00:30

	# output region area
	echo ${i},$(r.univar map=world_cell_area@land | grep sum | awk '{print $2}') >> $out_dir/region_us_area.csv

	###################################################################### worldclim

	### temperature

	par_name=tavg

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	### precipitation

	par_name=prec

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	### wind

	par_name=wind

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	### water vapor

	par_name=vapr

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	### radiation

	par_name=srad

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	###################################################################### landcover

	par_name=landcover

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	###################################################################### Glim

	par_name=glim

	for j in $(seq -f "%02g" 1 16); do

		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv
		
	done


	###################################################################### GLHYMPS	

	par_name=$(echo glhymps_permeability glhymps_porosity)

	for j in $par_name; do

		echo ${i},$(r.univar map=area_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${j}/area_${j}.csv
		
		echo ${i},$(r.univar map=${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${j}_t_area/${j}_t_area.csv
		
	done

	###################################################################### soilgrid250m

	par_name=$(echo soilgrids_clay soilgrids_fragment soilgrids_org soilgrids_pH soilgrids_sand soilgrids_silt soilgrids_soil_depth)

	for j in $par_name; do

		echo ${i},$(r.univar map=area_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${j}/area_${j}.csv
		
		echo ${i},$(r.univar map=${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${j}_t_area/${j}_t_area.csv
	done

	###################################################################### DEM and slope

	par_name=$(echo Geomorpho90m_dem Geomorpho90m_slope)

	for j in $par_name; do

		echo ${i},$(r.univar map=area_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${j}/area_${j}.csv
		
		echo ${i},$(r.univar map=${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${j}_t_area/${j}_t_area.csv

	done


 	###################################################################### PET and AET

	### pet

	par_name=pet

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	### aet

	par_name=aet

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	###################################################################### population	

	par_name=population

	for j in $par_name; do

		echo ${i},$(r.univar map=area_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${j}/area_${j}.csv
		
		echo ${i},$(r.univar map=${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${j}_t_area/${j}_t_area.csv

	done

	###################################################################### Soil moisture from cpc and willmott

	### cpc

	par_name=soil_moisture_cpc

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	# willmott

	par_name=soil_moisture_willmott

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	###################################################################### Runoff

	par_name=runoff

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	###################################################################### soil moisture terra

	par_name=soil_moisture_terra

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	###################################################################### npp	

	par_name=npp

	for j in $par_name; do

		echo ${i},$(r.univar map=area_${j}_sil@land | grep sum | awk '{print $2}') >> $out_dir/area_${j}/area_${j}.csv
		
		echo ${i},$(r.univar map=${j}_t_area_sil@land | grep sum | awk '{print $2}') >> $out_dir/${j}_t_area/${j}_t_area.csv

	done

done


EOF

# display end date and how much time elapsed
printf "\n\n"
date

sec_elapse=$SECONDS

echo "$(($sec_elapse / 3600))hrs $((($sec_elapse / 60) % 60))min $(($sec_elapse % 60))sec elapsed"
