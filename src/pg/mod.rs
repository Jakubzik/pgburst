use std::{fs::File, io::Write};

use clap::ValueEnum;

use crate::BurstConf;

pub struct PgObject {
    pub pg_type: PgObjectType,
    pub name: String,
    pub definition: String,
}
pub struct PgDb {
    pub name: String,
    pub schemas: Vec<PgSchema>,
}

pub struct PgSchema {
    pub name: String,
    pub pg_objects: Vec<PgObject>,
}

#[derive(Clone, Copy, PartialEq, ValueEnum)]
pub enum PgObjectType {
    Function,
    Trigger,
    View,
}

impl PgDb {
    /// Saves all selected views, functions and triggers to the
    /// configured folder.
    /// @param conf is for paths,
    /// @param tmp_folder stores original sql-files to enable UNDO-functionality.
    /// @returns a list of these files so that they can be
    /// monitored for changes (option 'watch').
    pub fn burst(self, conf: &BurstConf, tmp_folder: &str) -> Result<Vec<String>, std::io::Error> {
        let mut base_folder; // Utility
        let mut file_paths: Vec<String> = vec![];

        for i in 1..self.schemas.len() {
            if conf.schema_filter.is_none()
                || conf
                    .schema_filter
                    .as_ref()
                    .unwrap()
                    .contains(&self.schemas[i].name)
            {
                for j in 1..self.schemas[i].pg_objects.len() {
                    base_folder = format!(
                        "{}/{}/{}/{}s",
                        conf.burst_folder.as_ref().unwrap_or(&".".to_string()),
                        self.name,
                        self.schemas[i].name,
                        &self.schemas[i].pg_objects[j].pg_type.as_string()
                    );

                    // Add files to tmp-folder to generate
                    // undo-functionality when files are altered.
                    let tmp_folder_spec = format!(
                        "{}/{}/{}/{}s",
                        tmp_folder,
                        self.name,
                        &self.schemas[i].name,
                        &self.schemas[i].pg_objects[j].pg_type.as_string()
                    );

                    if is_selected(conf, &self.schemas[i].pg_objects[j]) {
                        write_sql(
                            &base_folder,
                            false,
                            &self.schemas[i].pg_objects[j],
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

    pub fn add_new(
        &mut self,
        schema: String,
        pg_object_type: PgObjectType,
        pg_object_name: String,
        f_def: String,
    ) {
        // Is this a schema we already know?
        let mut b_found = false;
        for i in 1..self.schemas.len() {
            if self.schemas[i].name == schema {
                b_found = true;
                self.schemas[i].pg_objects.push(PgObject {
                    pg_type: pg_object_type,
                    name: pg_object_name.clone(),
                    definition: f_def.clone(),
                });
            }
        }
        if !b_found {
            let v: Vec<PgObject> = vec![PgObject {
                pg_type: pg_object_type,
                name: pg_object_name,
                definition: f_def,
            }];
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
        }
    }

    pub fn get_sql(self) -> &'static str {
        match self {
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
    where n.nspname not in ('pg_catalog', 'information_schema')
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
    v_return: &mut Vec<String>,
) -> Result<(), std::io::Error> {
    std::fs::create_dir_all(folder.clone())?;
    let f_path = match is_tmp {
        false => format!("{folder}/{}.sql", pg_object.name),
        true => format!("{folder}/{}_undo.sql", pg_object.name),
    };

    if !is_tmp {
        v_return.push(f_path.clone());
    }

    let mut file = File::create(f_path)?;
    file.write_all(pg_object.definition.as_bytes())?;

    file.flush()?;
    Ok(())
}
