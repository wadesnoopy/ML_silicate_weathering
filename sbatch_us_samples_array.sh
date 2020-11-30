#!/bin/bash
#SBATCH --partition=day
#SBATCH --job-name=usgs
#SBATCH --ntasks=1 --nodes=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4000
#SBATCH --time=24:00:00
#SBATCH -o job-%x-slurm-%j-%A_%a.out
#SBATCH --array=1-629

# some job information
mem_bytes=$(</sys/fs/cgroup/memory/slurm/uid_${SLURM_JOB_UID}/job_${SLURM_JOB_ID}/memory.limit_in_bytes)
mem_gbytes=$(( $mem_bytes / 1024 **3 ))

echo "Starting at $(date)"
echo "Job submitted to the ${SLURM_JOB_PARTITION} partition, the default partition on ${SLURM_CLUSTER_NAME}"
echo "Job name: ${SLURM_JOB_NAME}, Job ID: ${SLURM_JOB_ID}"
echo "  I have ${SLURM_CPUS_ON_NODE} CPUs and ${mem_gbytes}GiB of RAM on compute node $(hostname)"


### load the module
module load GRASS/7.8.0-foss-2018a-Python-3.6.4

### directory

export project_dir=/gpfs/loomis/project/planavsky/sz243

export grassdb_dir=$project_dir/Grass/grassdb_world

export out_total_dir=$project_dir/Grass/output/silicate_weathering_2020_10_22

export out_dir=$out_total_dir/US_samples

# echo the current zone
echo this is zone z_$SLURM_ARRAY_TASK_ID
printf "\n\n"

export mapset_name=z_$SLURM_ARRAY_TASK_ID

echo this is mapset $mapset_name

# count time

SECONDS=0

# add more missing runs
# ls -rSl job-* | head -n 27 | awk '{print $9}' | cut -d'_' -f 2 | cut -d'.' -f 1 | tr "\n" ","


# calculate begin and end
# time for 23 samples: 36 minutes. so very quick!
max_files=14447
step=23
num_start=$(( (SLURM_ARRAY_TASK_ID-1)*step + 1 ))

num_end=$(( SLURM_ARRAY_TASK_ID*step ))

if [ $num_end -gt $max_files  ] ; then  num_end=$max_files ; fi 

export num_start
export num_end

# specifiy the snapped radius
export radius=3

################ enter grass and calculate

grass78 -text -f $grassdb_dir/world_30sec/${mapset_name} <<'EOF'

# set the region
g.region -d

lon_val=($(awk '{print $1}' $out_total_dir/usgs_stream_samples_snapped_radius_${radius}.out))
lat_val=($(awk '{print $2}' $out_total_dir/usgs_stream_samples_snapped_radius_${radius}.out))

# begin loop samples
for i in $(seq $num_start $num_end); do

	printf "\n\nnow is $i sample \n"

	# get the real index
	ind_i=$((i-1))

	# get the watershed
	r.water.outlet input=world_dir@land output=usgs_ws_${i} coordinates=${lon_val[$ind_i]},${lat_val[$ind_i]} --overwrite

	# this will speed things up
	g.region zoom=usgs_ws_${i}

	# output area
	echo ${i},$(r.stats -a usgs_ws_${i} | awk 'NR==1 {print $2}') >> $out_dir/usgs_ws_area.csv

	# output cell counts
	echo ${i},$(r.stats -c usgs_ws_${i} | awk 'NR==1 {print $2}') >> $out_dir/usgs_ws_cell_counts.csv

	###################################################################### worldclim

	### temperature

	par_name=tavg

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	### precipitation

	par_name=prec

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	### wind

	par_name=wind

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	### water vapor

	par_name=vapr

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	### radiation

	par_name=srad

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	###################################################################### landcover

	par_name=landcover

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	###################################################################### Glim

	par_name=glim

	for j in $(seq -f "%02g" 1 16); do

		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv
		
	done

	###################################################################### GUM

	### age

	par_name=gum_age

	for j in $(seq -f "%02g" 1 13); do

		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	### sed

	par_name=gum_sed

	for j in $(seq -f "%02g" 1 14); do

		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv
		
	done


	### size

	par_name=gum_size

	for j in $(seq -f "%02g" 1 8); do

		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv
		
	done


	###################################################################### GLHYMPS	

	par_name=$(echo glhymps_permeability glhymps_porosity)

	for j in $par_name; do

		echo ${i},$(r.univar map=area_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${j}/area_${j}.csv
		
		echo ${i},$(r.univar map=${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${j}_t_area/${j}_t_area.csv
	done

	###################################################################### soilgrid250m

	par_name=$(echo soilgrids_clay soilgrids_fragment soilgrids_org soilgrids_pH soilgrids_sand soilgrids_silt soilgrids_soil_depth)

	for j in $par_name; do

		echo ${i},$(r.univar map=area_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${j}/area_${j}.csv
		
		echo ${i},$(r.univar map=${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${j}_t_area/${j}_t_area.csv
	done

	###################################################################### DEM and slope

	par_name=$(echo Geomorpho90m_dem Geomorpho90m_slope)

	for j in $par_name; do

		echo ${i},$(r.univar map=area_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${j}/area_${j}.csv
		
		echo ${i},$(r.univar map=${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${j}_t_area/${j}_t_area.csv

	done


 	###################################################################### PET and AET

	### pet

	par_name=pet

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	### aet

	par_name=aet

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done


	###################################################################### population	

	par_name=population

	for j in $par_name; do

		echo ${i},$(r.univar map=area_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${j}/area_${j}.csv
		
		echo ${i},$(r.univar map=${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${j}_t_area/${j}_t_area.csv
	done

	###################################################################### Soil moisture from cpc and willmott

	### cpc

	par_name=soil_moisture_cpc

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	# willmott

	par_name=soil_moisture_willmott

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	###################################################################### Runoff

	par_name=runoff

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	###################################################################### soil_moisture_terra

	par_name=soil_moisture_terra

	for j in $(seq -f "%02g" 1 12); do

		echo ${i},$(r.univar map=area_${par_name}_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${par_name}/area_${par_name}_${j}.csv
		
		echo ${i},$(r.univar map=${par_name}_${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${par_name}_t_area/${par_name}_t_area_${j}.csv

	done

	###################################################################### npp	

	par_name=npp

	for j in $par_name; do

		echo ${i},$(r.univar map=area_${j}@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/area_${j}/area_${j}.csv
		
		echo ${i},$(r.univar map=${j}_t_area@land zone=usgs_ws_${i} | grep sum | awk '{print $2}') >> $out_dir/${j}_t_area/${j}_t_area.csv
	done


	###################################################################### reset	

	# remove the watershed
	g.remove -f type=raster name=usgs_ws_${i}

	# reset the region (important!!!)
	g.region -d

done


EOF

# display end date and how much time elapsed
printf "\n\n"
date

sec_elapse=$SECONDS

echo "$(($sec_elapse / 3600))hrs $((($sec_elapse / 60) % 60))min $(($sec_elapse % 60))sec elapsed"


# add more missing runs
# ls -rSl job-* | head -n 27 | awk '{print $9}' | cut -d'_' -f 2 | cut -d'.' -f 1 | tr "\n" ","