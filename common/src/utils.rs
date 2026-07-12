use std::fmt::Display;

use log::error;

pub trait LogUnwrap<T> {
    ///**Panics!**
    ///Attempts to unwrap the error and returns the value.
    ///If the value is an `Error`, this logs the error and then panics.
    fn unwrap_and_log(self, msg: &str) -> T;
}

impl<T, E: Display> LogUnwrap<T> for Result<T, E> {
    fn unwrap_and_log(self, msg: &str) -> T {
        self.unwrap_or_else(|e| {
            error!("{}\n{}", msg, e);
            panic!();
        })
    }
}

impl<T> LogUnwrap<T> for Option<T> {
    fn unwrap_and_log(self, msg: &str) -> T {
        self.unwrap_or_else(|| {
            error!("{}", msg);
            panic!();
        })
    }
}
