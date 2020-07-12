// このプログラムを読むときには次のことを意識すればいい。
// mbrはpbrとカーネルを含めたオフセット・サイズを知らなければならない。
// pbrはpbrの次のセクタから(つまり、カーネルをロードするコードだろう)のオフセット・サイズを知らなければならない。

// MBRへの書き込みに使用するオフセット
// OSNAMEは8byteで、先頭1byteが0でない場合OSが存在する。LEAD_SECは、LBA方式でそのパーティションが起動ディスクの先頭から何セクタ目に存在するかという情報へのオフセット。
// .equ	PART1_OSNAME, 462
// .equ	PART1_LEAD_SEC, 470
// .equ	PART2_OSNAME, 474
// .equ	PART2_LEAD_SEC, 482
// .equ	PART3_OSNAME, 486
// .equ	PART3_LEAD_SEC, 494
// .equ	PART4_OSNAME, 498
// .equ	PART4_LEAD_SEC, 506

#include<stdio.h>
#include<stdlib.h>
#include<string.h>

// These header are used in GetFileSize function.
#include<fcntl.h>
#include<sys/stat.h>
#include<sys/types.h>
#include<unistd.h>

long GetFileSize(const char *);

int main(int argc, char **argv){
	int i, j;
	FILE *Ifp, *Ofp;
	long file_size, disk_sec_offset = 1, disk_sec_size;
	char mbr_buffer[512], *image_buffer[4];
	long pbr_data[4][2];		// 0: Top address of OS-image on boot disk / 512, 1: OS-image size / 512
	char image_name[4][8];		// OS-name

	// Open the binary-mbr file.
	if((Ifp = fopen("./obj/mbr.bin", "rb")) == NULL){
		printf("Cannot open mbr.bin.\n");
		exit(1);
	}
	fread(mbr_buffer, 512, 1, Ifp);
	fclose(Ifp);

	// Open the output file.
	if((Ofp = fopen("DISK.img", "wb")) == NULL){
		printf("Cannot create DISK.img.\n");
		exit(1);
	}

	// Check the number of arguments.
	if(argc > 5){
		printf("You can only specify OS-image up to 4.\n");
		exit(1);
	}

	for(i = 1, j = 0; i < argc; i++, j++){
		if((Ifp = fopen(argv[i], "rb")) == NULL){
			printf("Cannot open %s.\n", argv[i]);
			exit(1);
		}

		// Save OS-name.
		memcpy(image_name[j], argv[i] + 6, 7);
		image_name[j][7] = '\0';

		// Get the file size.
		file_size = GetFileSize(argv[i]);

		// Covert the file size to the sector size.
		disk_sec_size = (file_size + 511) / 512;

		// Save information and update the next OS-offset.
		pbr_data[j][0] = disk_sec_offset;
		disk_sec_offset += disk_sec_size;

		// OS-size = OS-image-size - pbr-size
		pbr_data[j][1] = disk_sec_size - 1;

		if((image_buffer[j] = malloc(disk_sec_size * 512)) == NULL){
			printf("Cannot allocate memory for %s.\n", argv[i]);
			fclose(Ifp);
			exit(1);
		}
		fread(image_buffer[j], 1, disk_sec_size * 512, Ifp);
		fclose(Ifp);
	}

	// Write the info to mbr.
	// mbr-offset = the first sector of each OS-image, mbr-size = the size of each whole OS-image.
	for(i = 0; i < argc - 1; i++){
		memcpy(mbr_buffer + 462 + 12 * i, image_name[i], 8);
		memcpy(mbr_buffer + 470 + 12 * i, &pbr_data[i][0], 4);
	}
	fwrite(mbr_buffer, 512, 1, Ofp);	

	// Fix the info and write to pbr.
	for(i = 0; i < argc - 1; i++){
		// pbr-offset = the next sector of each OS-image's pbr, mbr-size = the size of each whole OS-image. (except pbr)
		pbr_data[i][0]++;
		memcpy(image_buffer[i] + 502, &pbr_data[i][0], 4);
		memcpy(image_buffer[i] + 506, &pbr_data[i][1], 4);
		fwrite(image_buffer[i], 1, (pbr_data[i][1] + 1) * 512, Ofp);
		free(image_buffer[i]);
	} 

	fclose(Ofp);
	return 0;
}

long GetFileSize(const char *FileName){
    FILE *fp;
    long file_size;
    struct stat stbuf;
    int fd;

    fd = open(FileName, O_RDONLY);
    if (fd == -1)
        printf("cant open file : %s.\n", FileName);

    fp = fdopen(fd, "rb");
    if (fp == NULL)
        printf("cant open file : %s.\n", FileName);

    if (fstat(fd, &stbuf) == -1)
        printf("cant get file state : %s.\n", FileName);

    file_size = stbuf.st_size;

    if (fclose(fp) != 0)
        printf("cant close file : %s.\n", FileName);

    return file_size;
}
