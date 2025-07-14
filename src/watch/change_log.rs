use crate::pg::PgObjectType;

pub struct Entry {
    pub(crate) origin_path: String,
    pub(crate) target_path: String,
    pub(crate) undo_path: String,
    pub(crate) count: usize,
    pub(crate) comment: String,
    pub(crate) pg_type: PgObjectType,
}

pub struct Log {
    pub entries: Vec<Entry>,
}

impl Log {
    pub fn add(&mut self, log_entry: Entry) {
        todo!()
    }

    pub fn write(self, folder: &str) {
        todo!()
    }
}
