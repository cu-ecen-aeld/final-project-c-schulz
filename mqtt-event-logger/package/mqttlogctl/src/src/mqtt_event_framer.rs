// Framer helper definition:
//
// feed()
// complete()
// reset()


// struct used to parse (JSON-like) objects,
// collects lines until one complete object has been received.
pub struct Framer {
    depth:     isize,
    in_string: bool,
    escaped:   bool,
}

impl Framer {
    // constructor
    pub fn new() -> Self {
        Self {
            depth:     0,
            in_string: false,
            escaped:   false,
        }
    }

    // feed one line into the parser
    pub fn feed(&mut self, line: &str) {
        for c in line.chars() {

            // reset after reading escaped characters
            if self.escaped {
                self.escaped = false;
                continue;
            }

            match c {
                // escape escape characters
                '\\' if self.in_string => {
                    self.escaped = true;
                }

                // escape strings
                '"' => {
                    self.in_string = !self.in_string;
                }

                // increase depth if a '{' is received
                '{' if !self.in_string => {
                    self.depth += 1;
                }

                // reduce depth if a '}' is received
                '}' if !self.in_string => {
                    self.depth -= 1;
                }

                // ignore all other characters
                _ => {}
            }
        }
    }

    // return true if a complete object has been received
    pub fn complete(&self) -> bool {
        self.depth == 0
    }

    // reset parser state for the next object
    pub fn reset(&mut self) {
        self.depth     = 0;
        self.in_string = false;
        self.escaped   = false;
    }
}