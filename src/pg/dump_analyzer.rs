pub struct Table {
    pub schema: String,
    pub name: String,
    pub create_sql: String,
    pub alterations_sql: String,
}

pub struct Tables {
    pub tables: Vec<Table>,
}

/// `sql` is the output of pg_dump, called with
/// --quote-all-identifiers.
///
/// The methods below analyze the sql into Table-
/// structs.
///
/// The `alterations_sql` contains setting ownership
/// and constraints -- every statement that begins
/// with "alter table schema.tname ..." or with
/// "alter table only schema.tname ..."
impl Tables {
    pub fn analyze(&mut self, sql: &str) {
        let mut sql_rest = sql.to_string();
        // We're going through the sql-text looking for
        // each "create table" statement, as long as there
        // still are these statements.
        while sql_rest.contains("CREATE TABLE ") {
            let start_position = sql_rest.find("CREATE TABLE ").unwrap();
            let create_statement =
                format!("{};", between(&sql_rest, "CREATE TABLE ", ";").to_string());

            sql_rest = sql_rest
                .chars()
                .into_iter()
                .skip(start_position + create_statement.len())
                .collect::<String>();

            let t_schema = get_schema_from_create_statement(&create_statement);

            let t_name = get_name_from_create_statement(&create_statement);

            self.tables.push(Table {
                schema: t_schema.to_owned(),
                name: t_name.to_owned(),
                create_sql: create_statement.to_string(),
                alterations_sql: get_alterations(&t_schema, &t_name, sql).to_owned(),
            });
        }
    }
}

/// The statement is "CREATE TABLE 'public'.'t_employee' (....)"
/// and this method -> public
fn get_schema_from_create_statement(create_statement: &str) -> String {
    let result = between(&create_statement, "CREATE TABLE ", ".");
    result
        .replace("\"", "")
        .replace("CREATE TABLE ", "")
        .to_string()
}

/// The statement is "CREATE TABLE 'public'.'t_employee' (....)"
/// and this method -> t_employee
fn get_name_from_create_statement(create_statement: &str) -> String {
    let result = between(&create_statement, ".", " ");
    result.replace("\"", "").replace(".", "").to_string()
}

/// returns a collection of all SQL-statements
/// with "alter table schema.tname ..." or with
/// "alter table only schema.tname ..."
fn get_alterations(schema: &str, t_name: &str, full_sql: &str) -> String {
    let mut sql_rest = full_sql.to_string();
    let t_name_qualified = format!("\"{}\".\"{}\"", schema, t_name);
    let tt = format!("ALTER TABLE {}", t_name_qualified);

    let mut alterations: Vec<String> = vec![];
    while sql_rest.contains(&tt) {
        let start_position = sql_rest.find(&tt).unwrap();
        let sql_alteration = between(&sql_rest, &tt, ";");
        alterations.push(sql_alteration.to_string());
        sql_rest = sql_rest
            .chars()
            .into_iter()
            .skip(start_position + sql_alteration.len())
            .collect::<String>();
    }

    let tt = format!("ALTER TABLE ONLY {}", t_name_qualified);
    sql_rest = full_sql.to_string();

    // let mut alterations: Vec<String> = vec![];
    while sql_rest.contains(&tt) {
        let start_position = sql_rest.find(&tt).unwrap();
        let sql_alteration = between(&sql_rest, &tt, ";");
        alterations.push(sql_alteration.to_string());
        sql_rest = sql_rest
            .chars()
            .into_iter()
            .skip(start_position + sql_alteration.len())
            .collect::<String>();
    }
    alterations.join(";\n\n")
}

pub fn between<'a>(source: &'a str, start: &'a str, end: &'a str) -> &'a str {
    let start_position = source.find(start);

    if start_position.is_some() {
        // let start_position = start_position.unwrap() + start.len();
        let start_position = start_position.unwrap(); // + start.len();
        let source = &source[start_position..];
        let end_position = source.find(end).unwrap_or_default();
        return &source[..end_position];
    }
    return "";
}
