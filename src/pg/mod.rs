use std::{fs::File, io::Write, path::PathBuf};
pub mod dump_analyzer;

use clap::ValueEnum;

use crate::BurstConf;

#[derive(Clone, Debug)]
pub struct PgObject {
    pub pg_type: PgObjectType,
    pub name: String,
    pub definition: String,
    pub number_of_changes: usize,
}

pub struct PgDb {
    pub name: String,
    pub schemas: Vec<PgSchema>,
    pub base_folder: String,
    pub tmp_folder: String,
}

// pub struct PgSchema<'a> {
pub struct PgSchema {
    pub name: String,
    // pub pg_objects: Vec<&'a mut PgObject>,
    pub pg_objects: Vec<PgObject>,
}

#[derive(Clone, Copy, PartialEq, ValueEnum, Debug)]
pub enum PgObjectType {
    Function,
    Trigger,
    View,
    Type,
    Sequence,
    Table,
}

impl PgObject {
    // We need to keep track of the changes that
    // are commited so we have unique filenames
    // for these iterations in the `burst_skript`
    // folder
    pub fn increase_number_of_changes(&mut self) {
        self.number_of_changes += 1;
    }
}

impl PgDb {
    /// Saves all selected views, functions and triggers to the
    /// configured folder.
    /// @param conf is for paths,
    /// @param tmp_folder stores original sql-files to enable UNDO-functionality.
    /// @returns a list of these files so that they can be
    /// monitored for changes (option 'watch').
    // pub fn burst(self, conf: &BurstConf, tmp_folder: &str) -> Result<Vec<PathBuf>, std::io::Error> {
    pub fn burst(
        &mut self,
        conf: &BurstConf,
        tmp_folder: &str,
    ) -> Result<Vec<PathBuf>, std::io::Error> {
        self.base_folder = conf
            .burst_folder
            .as_ref()
            .unwrap_or(&".".to_string())
            .clone();

        self.tmp_folder = tmp_folder.to_string();
        let mut file_paths: Vec<PathBuf> = vec![];

        for i in 0..self.schemas.len() {
            if conf.schema_filter.is_none()
                || conf
                    .schema_filter
                    .as_ref()
                    .unwrap()
                    .contains(&self.schemas[i].name)
            {
                for j in 0..self.schemas[i].pg_objects.len() {
                    let base_folder = format!(
                        "{}/{}/{}/{}s",
                        self.base_folder,
                        self.name,
                        self.schemas[i].name,
                        &self.schemas[i].pg_objects[j].pg_type.as_string()
                    );

                    // Add files to tmp-folder to generate
                    // undo-functionality when files are altered.
                    let tmp_folder_spec = format!(
                        "{}/{}/{}/{}s",
                        self.tmp_folder,
                        self.name,
                        &self.schemas[i].name,
                        &self.schemas[i].pg_objects[j].pg_type.as_string()
                    );

                    if is_selected(conf, &self.schemas[i].pg_objects[j]) {
                        write_sql(
                            &base_folder,
                            false,
                            &self.schemas[i].pg_objects[j],
                            // &mut pg_objects,
                            &mut file_paths,
                        )?;

                        write_sql(
                            &tmp_folder_spec,
                            true,
                            &self.schemas[i].pg_objects[j],
                            &mut file_paths,
                        )?;
                    }
                }
            }
        }
        Ok(file_paths)
    }

    // We want to get the object to increase its
    // changes-counter (so that we can track multiple
    // changes of the same file).
    //
    // .get_object identifies the object using its path. The path
    // ends in:
    //
    // `db_name/schema/type/object_name.sql`
    //
    // This can be used to identify the corresponding
    // object schema[name].type[name].object[name_without_.sql]
    pub fn get_object(&mut self, s_path: &PathBuf) -> Option<&mut PgObject> {
        let mut b_is_component_of_db = false;
        let mut c_schema = "";
        let mut c_plural_of_type; // = "".to_string();
        let mut c_type_clean = "".to_string();
        let mut c_name = "";

        // We're looping the path components until
        // we reach the db_name (b_is_component is set to `true`),
        // then we set the type,
        // and then the name.
        for component in s_path.components() {
            if b_is_component_of_db {
                // 1st is the schema,
                if c_schema.is_empty() {
                    c_schema = component.as_os_str().to_str().unwrap();
                } else {
                    // 2nd is the type
                    if c_type_clean.is_empty() {
                        // Paths of types are in the plural,
                        // db_name/tableS, db_name/functionS etc.,
                        // so we .pop() this part of the path:
                        c_plural_of_type = component.as_os_str().to_string_lossy().to_string();
                        c_plural_of_type.pop();
                        c_type_clean = c_plural_of_type.to_lowercase();
                    } else {
                        // last one is the name
                        c_name = component.as_os_str().to_str().unwrap();
                    }
                }
            }
            if component.as_os_str().to_string_lossy() == self.name {
                b_is_component_of_db = true;
            }
        }

        let mut obj: Option<&mut PgObject> = None;

        if let Some(schema) = self
            .schemas
            .iter_mut()
            .find(|schema| schema.name == c_schema)
        {
            obj = schema.pg_objects.iter_mut().find(|p_obj| {
                p_obj.name == c_name[0..c_name.len() - 4]
                    && p_obj.pg_type.as_string().to_lowercase() == c_type_clean
            });
        }
        obj
    }

    pub fn add_new(
        &mut self,
        schema: String,
        pg_object_type: PgObjectType,
        pg_object_name: String,
        f_def: String,
    ) {
        // Is this a schema we already know?
        let mut b_schema_already_known = false;
        let obj = PgObject {
            pg_type: pg_object_type,
            name: pg_object_name,
            definition: f_def,
            number_of_changes: 0,
        };

        // Add the object to the schema, if there already
        // is a schema ...
        for i in 0..self.schemas.len() {
            if self.schemas[i].name == schema {
                b_schema_already_known = true;
                self.schemas[i].pg_objects.push(obj.clone());
            }
        }

        // ... or, if there's no schema yet, create
        // the schema and add the object
        if !b_schema_already_known {
            let mut v: Vec<PgObject> = vec![];
            v.push(obj);
            // let v: Vec<&mut PgObject> = vec![PgObject {
            //     pg_type: pg_object_type,
            //     name: pg_object_name,
            //     definition: f_def,
            // }];
            self.schemas.push(PgSchema {
                name: schema,
                pg_objects: v,
            });
        }
    }
}

impl PgObjectType {
    pub fn as_string(self) -> &'static str {
        match self {
            PgObjectType::Function => "function",
            PgObjectType::Trigger => "trigger",
            PgObjectType::View => "view",
            PgObjectType::Type => "type",
            PgObjectType::Sequence => "sequence",
            PgObjectType::Table => "table",
        }
    }

    ///
    /// Type (currently only composite and enum, not range or complex) is:
    ///+------------+--------------+------------------------+-------------+-----------+------------------+-------------+-------------+
    ///| burst_type | schema_name  | obj_name               | column_name | data_type | ordinal_position | is_required | description |
    ///|------------+--------------+------------------------+-------------+-----------+------------------+-------------+-------------|
    ///| composite  | ap_tests     | ap_tests.typ_composit  | f1          | integer   | 1                | False       |             |
    ///| composite  | ap_tests     | ap_tests.typ_composit  | f2          | text      | 2                | False       |             |
    ///| enum       | ap_tests     | bug_status             | new         |           | 1                | False       |             |
    ///| enum       | ap_tests     | bug_status             | open        |           | 1                | False       |             |
    ///| enum       | ap_tests     | bug_status             | closed      |           | 1                | False       |             |
    ///| composite  | bewerber_api | bewerber_api.jwt_token | token       | text      | 1                | False       |             |
    ///+------------+--------------+------------------------+-------------+-----------+------------------+-------------+-------------+
    pub fn get_sql(self) -> &'static str {
        match self {
            // PgObjectType::Table => {
            //     ""
            //     }

            PgObjectType::Sequence => {
                "SELECT schemaname as schema_name, sequencename as obj_name, 'CREATE SEQUENCE \"' || schemaname || '\".\"' || sequencename || '\" as ' || data_type ||  ' INCREMENT BY ' || increment_by ||  ' START WITH ' || start_value ||  ' MINVALUE ' || min_value ||  ' MAXVALUE ' || max_value ||  ' CACHE ' || cache_size || case when cycle then ' cycle ' else '' end || ';'
                      AS definition
                FROM pg_sequences;"

                },
            PgObjectType::Type => {
                "WITH types AS (
                    SELECT n.nspname,
                            pg_catalog.format_type ( t.oid, NULL ) AS obj_name,
                            CASE
                                WHEN t.typrelid != 0 THEN CAST ( 'tuple' AS pg_catalog.text )
                                WHEN t.typlen < 0 THEN CAST ( 'var' AS pg_catalog.text )
                                ELSE CAST ( t.typlen AS pg_catalog.text )
                                END AS obj_type,
                            coalesce ( pg_catalog.obj_description ( t.oid, 'pg_type' ), '' ) AS description
                        FROM pg_catalog.pg_type t
                        JOIN pg_catalog.pg_namespace n
                            ON n.oid = t.typnamespace
                        WHERE ( t.typrelid = 0
                                OR ( SELECT c.relkind = 'c'
                                        FROM pg_catalog.pg_class c
                                        WHERE c.oid = t.typrelid ) )
                            AND NOT EXISTS (
                                    SELECT 1
                                        FROM pg_catalog.pg_type el
                                        WHERE el.oid = t.typelem
                                        AND el.typarray = t.oid )
                            AND n.nspname <> 'pg_catalog'
                            AND n.nspname <> 'information_schema'
                            AND n.nspname !~ '^pg_toast'
                ),
                cols AS (
                    SELECT n.nspname::text AS schema_name,
                            pg_catalog.format_type ( t.oid, NULL ) AS obj_name,
                            a.attname::text AS column_name,
                            pg_catalog.format_type ( a.atttypid, a.atttypmod ) AS data_type,
                            a.attnotnull AS is_required,
                            a.attnum AS ordinal_position,
                            pg_catalog.col_description ( a.attrelid, a.attnum ) AS description
                        FROM pg_catalog.pg_attribute a
                        JOIN pg_catalog.pg_type t
                            ON a.attrelid = t.typrelid
                        JOIN pg_catalog.pg_namespace n
                            ON ( n.oid = t.typnamespace )
                        JOIN types
                            ON ( types.nspname = n.nspname
                                AND types.obj_name = pg_catalog.format_type ( t.oid, NULL ) )
                        WHERE a.attnum > 0
                            AND NOT a.attisdropped
                )
                SELECT 'composite' as burst_type, 
                      cols.schema_name,
                        cols.obj_name,
                        cols.column_name,
                        cols.data_type,
                        cols.ordinal_position,
                        cols.is_required,
                        coalesce ( cols.description, '' ) AS description
                    FROM cols
                union
                SELECT
                    'enum' as burst_type,
                    n.nspname as schema_name,
                    pg_type.typname as type_name, 
                    pg_enum.enumlabel as label,'',1,false,''
                FROM
                    pg_type, pg_catalog.pg_namespace n, pg_enum
                where
                    n.oid=pg_type.typnamespace and 
                    pg_enum.enumtypid = pg_type.oid


                    ORDER BY schema_name,
                            obj_name,
                            ordinal_position 
                "
            }
            PgObjectType::Function => {
                "select n.nspname as schema_name,
               p.proname as obj_name,
               case p.prokind 
                    when 'f' then 'FUNCTION'
                    when 'p' then 'PROCEDURE'
                    when 'a' then 'AGGREGATE'
                    when 'w' then 'WINDOW'
                    end as kind,
               l.lanname as language,
               case when l.lanname = 'internal' then p.prosrc
                    else pg_get_functiondef(p.oid)
                    end as definition,
               pg_get_function_arguments(p.oid) as arguments,
               t.typname as return_type
            from pg_proc p
            left join pg_namespace n on p.pronamespace = n.oid
            left join pg_language l on p.prolang = l.oid
            left join pg_type t on t.oid = p.prorettype 
            where n.nspname not in ('pg_catalog', 'information_schema') and l.lanname != 'internal'
            order by schema_name, obj_name;"
            }
            PgObjectType::Trigger => {
                "select event_object_schema as schema_name,
        event_object_table as table_name,
        trigger_schema,
        trigger_name as obj_name,
        string_agg(event_manipulation, ',') as event,
        action_timing as activation,
        action_condition as condition,
        'create trigger '|| trigger_name || action_timing || ' ' || string_agg(event_manipulation, ',') || ' on '  || '\"' || event_object_schema || '\".\"' || event_object_table || '\" for each row ' || action_statement as definition 
             from information_schema.triggers
             group by 1,2,3,4,6,7, action_statement
             order by schema_name,
          table_name;"
                // 88gelöscht
            }
            PgObjectType::View => "select schemaname as schema_name, viewname as obj_name, 'create or replace view \"'|| schemaname || '\".\"'|| viewname || '\" AS ' || definition as definition from pg_catalog.pg_views where schemaname not in ('pg_catalog', 'information_schema') ",
            PgObjectType::Table => "# Objekttype table must be calculated via pgdump"
        }
    }
}

/// Called while iterating through the postgres objects:
/// is it an object that we want (i.e. that meets the
/// criteria the user specified on invokation)
fn is_selected(conf: &BurstConf, pg_object: &PgObject) -> bool {
    // filter criterion for sql definition met?
    let mut b_selected =
        conf.find.is_none() || pg_object.definition.contains(conf.find.as_ref().unwrap());

    // filter criteria for object type (function, view, trigger) met?
    b_selected = b_selected
        && (conf.objects_filter.is_none()
            || conf
                .objects_filter
                .as_ref()
                .unwrap()
                .contains(&pg_object.pg_type));

    // filter criterion for object name met?
    b_selected = b_selected
        && (conf.name_filter.is_none()
            || pg_object.name.contains(conf.name_filter.as_ref().unwrap()));

    b_selected
}

// Repetitive task of writing a file with this name and
// contents to the burst_folder (1) and, in order to be
// able to perform undo later, into a tmp-folder
fn write_sql(
    folder: &String,
    is_tmp: bool,
    pg_object: &PgObject,
    v_return: &mut Vec<PathBuf>,
    // v_return: &mut Vec<PgObject>,
) -> Result<(), std::io::Error> {
    // std::fs::create_dir_all(folder.clone())?;
    std::fs::create_dir_all(folder.clone())?;
    let f_path = match is_tmp {
        false => format!("{folder}/{}.sql", pg_object.name),
        true => format!("{folder}/{}_undo.sql", pg_object.name),
    };

    if !is_tmp {
        v_return.push(PathBuf::from(&f_path));
    }

    let mut file = File::create(&f_path)?;
    file.write_all(pg_object.definition.as_bytes())?;

    file.flush()?;
    Ok(())
}
