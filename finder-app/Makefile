# Toolchain prefix (empty by default)
CROSS_COMPILE ?=

CC      := $(CROSS_COMPILE)gcc
CFLAGS  := -Wall -Wextra -Werror -std=c11
TARGET  := writer
SRC     := writer.c
OBJ     := $(SRC:.c=.o)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(TARGET) *.o

