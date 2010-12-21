##
## contains functions to noisify curves
##
##

import numpy as np
import create_database


# will be used by each noisification method to put a record in source
# and tfe values in measurements
def enter_record(tfe,cursor,source_id,sigma_level):
    sql_cmd = """select number_points,classification,c1,e1,c2,e2,survey from sources where source_id=""" + repr(source_id)
    cursor.execute(sql_cmd)
    source_info = list(cursor.fetchall()[0])
    sql_cmd = """SELECT datetime('now')"""
    cursor.execute(sql_cmd)
    db_info = cursor.fetchall()
    source_info.append(db_info[0][0])
    source_info.append(sigma_level)
    source_info.append(source_id)
    sql_cmd = """insert into sources(number_points, classification, c1, e1, c2, e2, survey,date,noisification,original_source_id) values (?,?,?,?,?,?,?,?,?,?)"""
    cursor.execute(sql_cmd, source_info)

    # find last insert number
    cursor.execute("""SELECT last_insert_rowid()""")
    last_id = cursor.fetchall()[0][0]

    # now insert measurement data
    create_database.insert_measurements(cursor,last_id,tfe)



def sigma_noisification(cursor,source_id,sigma_level=1):
    # probably should make a check that we are not noisifying
    # something that is already noisified
    tfe = create_database.get_measurements(source_id,cursor)
    tfe[:,1] = np.random.normal(loc=0,scale=tfe[:,2]) + tfe[:,1]
    enter_record(tfe,cursor,source_id,sigma_level)
    print "source " + repr(source_id) + " noisified"
