/* -------------------------------------------------------------------------- */
/* Copyright 2002-2020, OpenNebula Project, OpenNebula Systems                */
/*                                                                            */
/* Licensed under the Apache License, Version 2.0 (the "License"); you may    */
/* not use this file except in compliance with the License. You may obtain    */
/* a copy of the License at                                                   */
/*                                                                            */
/* http://www.apache.org/licenses/LICENSE-2.0                                 */
/*                                                                            */
/* Unless required by applicable law or agreed to in writing, software        */
/* distributed under the License is distributed on an "AS IS" BASIS,          */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   */
/* See the License for the specific language governing permissions and        */
/* limitations under the License.                                             */
/* -------------------------------------------------------------------------- */

#ifndef VNTEMPLATE_POOL_H_
#define VNTEMPLATE_POOL_H_

#include "PoolSQL.h"
#include "VNTemplate.h"

/**
 *  The VNetTemplate Pool class.
 */
class VNTemplatePool : public PoolSQL
{
public:

    VNTemplatePool(SqlDB * db) : PoolSQL(db, VNTemplate::table){};

    ~VNTemplatePool(){};

    /**
     *  Allocates a new object, writting it in the pool database. No memory is
     *  allocated for the object.
     *    @param uid user id (the owner of the Template)
     *    @param gid the id of the group this object is assigned to
     *    @param uname user name
     *    @param gname group name
     *    @param umask permissions umask
     *    @param template_contents a VM Template object
     *    @param oid the id assigned to the Template
     *    @param error_str Returns the error reason, if any
     *
     *    @return the oid assigned to the object, -1 in case of failure
     */
    int allocate(int                      uid,
                 int                      gid,
                 const string&            uname,
                 const string&            gname,
                 int                      umask,
                 VirtualNetworkTemplate * template_contents,
                 int *                    oid,
                 string&                  error_str);

    /**
     *  Gets an object from the pool (if needed the object is loaded from the
     *  database).
     *   @param oid the object unique identifier
     *   @param lock locks the object if true
     *
     *   @return a pointer to the object, 0 in case of failure
     */
    VNTemplate * get(int oid)
    {
        return static_cast<VNTemplate *>(PoolSQL::get(oid));
    };

    /**
     *  Gets an object from the pool (if needed the object is loaded from the
     *  database).
     *   @param oid the object unique identifier
     *
     *   @return a pointer to the object, 0 in case of failure
     */
    VNTemplate * get_ro(int oid)
    {
        return static_cast<VNTemplate *>(PoolSQL::get_ro(oid));
    };

    /**
     *  Dumps the pool in XML format. A filter can be also added to the
     *  query
     *  @param oss the output stream to dump the pool contents
     *  @param where filter for the objects, defaults to all
     *  @param sid first element used for pagination
     *  @param eid last element used for pagination, -1 to disable
     *  @param desc descending order of pool elements
     *
     *  @return 0 on success
     */
    int dump(std::string& oss, const std::string& where, int sid, int eid,
        bool desc)
    {
        return PoolSQL::dump(oss, "VNTEMPLATE_POOL", "body", VNTemplate::table,
                where, sid, eid, desc);
    };

    /**
     *  Bootstraps the database table(s) associated to the pool
     *    @return 0 on success
     */
    static int bootstrap(SqlDB *_db)
    {
        return VNTemplate::bootstrap(_db);
    };

private:
    /**
     *  Factory method to produce VNTemplate objects
     *    @return a pointer to the new VNTemplate
     */
    PoolObjectSQL * create()
    {
        return new VNTemplate(-1,-1,-1,"","",0,0);
    };
};

#endif /*VNTEMPLATE_POOL_H_*/
