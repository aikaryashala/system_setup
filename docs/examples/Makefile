CC      = clang
CFLAGS  = -g -O0 -Wall -Wextra -std=c17
TARGET  = hello

# From https://aikaryashala.com/system_setup/07_install_binary/
#
# The indented lines below MUST start with a real tab character, not spaces.
# "missing separator" is what make says when they do not.

$(TARGET): hello.c
	$(CC) $(CFLAGS) -o $(TARGET) hello.c

debug: CFLAGS += -fsanitize=address
debug: clean $(TARGET)

clean:
	rm -f $(TARGET) overflow

.PHONY: debug clean
