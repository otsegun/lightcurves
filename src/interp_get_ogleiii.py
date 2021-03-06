########## 
########## 
########## READ IN AND DERIVE FEATURES FOR OGLE III 
########## LIGHT CURVES
##########
########## by James Long 
########## date: 8/22/2011 
########## 


import random
import noisification
import db_output
import derive_features
import synthetic_data
import visualize
import create_database
import visualize
import numpy as np
import sqlite3
import scipy.stats
import math
import smoothers
import kde


## put results in a list
def tolist(db_info):
 list1 = []
 for i in db_info:
  list1.append(i[0])
 return(list1)


## make and test connection to the database
features_file = "../db/derived_features_list.txt"
connection = sqlite3.connect('../db/ogleiiiall.db')
cursor = connection.cursor()
create_database.create_db(cursor,features_file=features_file,REMOVE_RECORDS=True)
connection.commit()
folder = "../data/OGLEIII/mira"
create_database.ingest_many_tfes(folder,
                                ".dat",
                                cursor,
                                connection,
                                survey="ogle",
                                classification="Mira")
connection.commit()
print "obtained miras . . ."
folder = "../data/OGLEIII/classical-cepheid-fundamental"
create_database.ingest_many_tfes(folder,
                                ".dat",
                                cursor,
                                connection,
                                survey="ogle",
                                classification="Classical Cepheid")
connection.commit()
print "obtained classical cepheids . . ."
folder = "../data/OGLEIII/rr-ab"
create_database.ingest_many_tfes(folder,
                                ".dat",
                                cursor,
                                connection,
                                survey="ogle",
                                classification="RR Lyrae AB")
connection.commit()
print "obtained rr lyraes ab . . ."




## make a nice view of the features table
sql_cmd = """CREATE VIEW IF NOT EXISTS features_short AS SELECT source_id,freq1_harmonics_freq_0,std,max,weighted_average FROM features"""
cursor.execute(sql_cmd)

## make a nice view of the features table
sql_cmd = """CREATE VIEW IF NOT EXISTS sources_short AS SELECT source_id,original_source_id,classification,noisification,noise_args,true_period FROM sources"""
cursor.execute(sql_cmd)



## examine what we have collected
sql_cmd = """SELECT source_id,survey,number_points,classification,xml_filename FROM sources"""
cursor.execute(sql_cmd)
db_info = cursor.fetchall()
total_points = 0
for i in db_info:
    print i
    total_points = total_points + i[2]

## SANITY CHECK
print "the total number of points is:"
print total_points
sql_cmd = """SELECT count(*) FROM measurements"""
cursor.execute(sql_cmd)
db_info = cursor.fetchall()
print "the number of entries in measurements table is:"
print db_info

connection.commit()


##
## make density plot of number of points by class
##
sql_cmd = """SELECT classification,number_points FROM sources"""
cursor.execute(sql_cmd)
db_info = cursor.fetchall()

points_dict = {}
for i in db_info:
  try:
    points_dict[i[0]].append(i[1])
  except KeyError:
    points_dict[i[0]] = [i[1]]


for i in points_dict.keys():
  points_dict[i] = np.array(points_dict[i],dtype='float32')


reload(kde)
kde.produceKDE(points_dict)





## DERIVE FEATURES
sql_cmd = """SELECT source_id FROM sources"""        
cursor.execute(sql_cmd)
db_info = cursor.fetchall()
source_ids = tolist(db_info)
noise_dict = noisification.get_noisification_dict()
derive_features.derive_features_par(source_ids,noise_dict,cursor,connection,number_processors=2,delete_existing=True)


##########
########## OUTPUT RESULTS
##########
## output all sources to R file for analysis
sql_cmd = """SELECT source_id FROM sources"""
cursor.execute(sql_cmd)
db_info = cursor.fetchall()
source_ids = tolist(db_info)
db_output.outputRfile(source_ids,cursor,'../data_processed/ogleIIIall-fund.dat')

## output tfes
sql_cmd = """SELECT source_id FROM sources WHERE original_source_id = source_id"""
cursor.execute(sql_cmd)
db_info = cursor.fetchall()
source_ids = tolist(db_info)
db_output.tfeOutput(source_ids,cursor,'../data_processed/ogleIIIall-fund-tfe.dat')


connection.commit()

