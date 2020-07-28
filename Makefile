#################
##### macro #####
#################

SRC_DIR	= ./src
LS_DIR	= ./ls
OBJ_DIR	= ./obj
IMG_DIR	= ./img

MBR_SRC = $(SRC_DIR)/mbr.s
MBR_LS  = $(LS_DIR)/mbr.ls
MBR_BIN = $(OBJ_DIR)/mbr.bin

TOOL_SRC= $(SRC_DIR)/make_part_image.c
TOOL_EXE= $(OBJ_DIR)/make_part_image

KRNL_IMG= $(IMG_DIR)/*.img
DISK_IMG= DISK.img



#######################
##### create file #####
#######################

.SILENT:

$(DISK_IMG):

$(MBR_BIN): $(MBR_SRC) $(MBR_LS)
	@gcc -nostdlib -T$(MBR_LS) $(MBR_SRC) -o $@

$(TOOL_EXE): $(TOOL_SRC)
	@gcc $? -o $@

$(DISK_IMG): $(MBR_BIN) $(TOOL_EXE) $(KRNL_IMG)
	@./$(TOOL_EXE) $(KRNL_IMG)



######################
##### operations #####
######################

run: $(DISK_IMG)
	@qemu-system-i386 -L . -m 100 -localtime -vga std -drive file=$?,format=raw

clean:
	@rm -f $(MBR_BIN) $(TOOL_EXE) $(DISK_IMG) 
