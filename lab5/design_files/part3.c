/* This files provides address values that exist in the system */

#define SDRAM_BASE            0xC0000000
#define FPGA_ONCHIP_BASE      0xC8000000
#define FPGA_CHAR_BASE        0xC9000000

/* Cyclone V FPGA devices */
#define LEDR_BASE             0xFF200000
#define HEX3_HEX0_BASE        0xFF200020
#define HEX5_HEX4_BASE        0xFF200030
#define SW_BASE               0xFF200040
#define KEY_BASE              0xFF200050
#define TIMER_BASE            0xFF202000
#define PIXEL_BUF_CTRL_BASE   0xFF203020
#define CHAR_BUF_CTRL_BASE    0xFF203030

/* VGA colors */
#define WHITE 0xFFFF
#define YELLOW 0xFFE0
#define RED 0xF800
#define GREEN 0x07E0
#define BLUE 0x001F
#define CYAN 0x07FF
#define MAGENTA 0xF81F
#define GREY 0xC618
#define PINK 0xFC18
#define ORANGE 0xFC00
int colors[10] = {WHITE, YELLOW, RED, GREEN, BLUE, CYAN, MAGENTA, GREY, PINK, ORANGE};

#define ABS(x) (((x) > 0) ? (x) : -(x))

/* Screen size. */
#define RESOLUTION_X 320
#define RESOLUTION_Y 240

/* Constants for animation */
#define BOX_LEN 2
#define NUM_BOXES 8

#define FALSE 0
#define TRUE 1

#include <stdlib.h>
#include <stdio.h>
#include <time.h>


// Begin part3.c code for Lab 7


volatile int pixel_buffer_start; // global variable
void plot_pixel(int baseAdr, int x, int y, short int colour) {
    *(short int *)(baseAdr + (y << 10) + (x << 1)) = colour;
}
void clear_screen() {
    int i,j;
    for (i = 0; i < RESOLUTION_X; i++) {
        for (j = 0; j < RESOLUTION_Y; j++) {
            plot_pixel(pixel_buffer_start, i, j, 0x0000);
        }
    }
}
void swap(int* a, int* b) {
    int temp = *a;
    *a = *b;
    *b = temp;
}
void wait_for_vsync() {
    volatile int * pixel_ctrl_ptr = (int *) PIXEL_BUF_CTRL_BASE;

    volatile int status;

    *pixel_ctrl_ptr = 1;

    status = *(pixel_ctrl_ptr + 3);
    while ((status & 0x01) != 0x0) {
        status = *(pixel_ctrl_ptr + 3);
    }
}
void draw_line(int x0, int y0, int x1, int y1, short int colour) {
    int is_steep = (ABS(y1 - y0) > ABS(x1 - x0)) ? TRUE : FALSE;
    if (is_steep){
        swap(&x0, &y0);
        swap(&x1, &y1);
    } 
    if (x0 > x1){
        swap(&x0, &x1);
        swap(&y0, &y1);
    }

    int delX = abs(x1 - x0);
    int delY = abs(y1 - y0);
    int error = -(delY / 2);
    int y = y0;
    int y_step = y0 < y1 ? 1 : -1;
    int x;
    for (x = x0; x <= x1; x++)
    {
        if (is_steep){
            plot_pixel(pixel_buffer_start, y,x,colour);
        } else {
            plot_pixel(pixel_buffer_start, x,y,colour);
        }
        error = error + delY;
        if (error >= 0)
        {
            y = y + y_step;
            error = error - delX;
        }
    }
}
void draw_box(int boxes_array[NUM_BOXES][5]) {
    int i,j,k;
    for (i = 0; i < NUM_BOXES; i++) {
        for (j = 0; j <= BOX_LEN; j++) { //draw the box
            for (k = 0; k <= BOX_LEN; k++) {
                plot_pixel(pixel_buffer_start, boxes_array[i][0] + j, boxes_array[i][1] + k, boxes_array[i][4]);
            }
        }
        if (i == (NUM_BOXES - 1)) { //it's the last box and needs to be connect with the first box
            draw_line(boxes_array[i][0], boxes_array[i][1], boxes_array[0][0], boxes_array[0][1], boxes_array[i][4]);
        }
        else { // connect one box to the next
            draw_line(boxes_array[i][0], boxes_array[i][1], boxes_array[i+1][0], boxes_array[i+1][1], boxes_array[i][4]);
        }
    }
}
int main(void)
{
    volatile int * pixel_ctrl_ptr = (int *)0xFF203020;
    // declare other variables(not shown)
    // initialize location and direction of rectangles(not shown)

    /* set front pixel buffer to start of FPGA On-chip memory */
    *(pixel_ctrl_ptr + 1) = 0xC8000000; // first store the address in the 
                                        // back buffer
    /* now, swap the front/back buffers, to set the front buffer location */
    wait_for_vsync();
    /* initialize a pointer to the pixel buffer, used by drawing functions */
    pixel_buffer_start = *pixel_ctrl_ptr;
    clear_screen(); // pixel_buffer_start points to the pixel buffer
    /* set back pixel buffer to start of SDRAM memory */
    *(pixel_ctrl_ptr + 1) = 0xC0000000;
    pixel_buffer_start = *(pixel_ctrl_ptr + 1); // we draw on the back buffer
    clear_screen(); // pixel_buffer_start points to the pixel buffer

    /* BOX DATA STRUCTURE

    2D Array. 

    8 Boxes which each have 5 properties. 
    1. X loc
    2. Y loc
    3. delX (Which direction to move the box in the X coords)
    4. delY (Which direction to move the box in the Y coords)
    5. Its colour
    
    The previous location boxes for the current and previous buffers will have:
    1. X Loc
    2. Y loc
    3. Colour
    */
    srand(time(0)); 
    int i;
    int current_array_boxes[NUM_BOXES][5];
    int prev_array_boxes[NUM_BOXES][5];
    int new_prev_array_boxes[NUM_BOXES][5];
    //develope the random boxes
    for (i = 0; i < NUM_BOXES; i++){
        //get a random colour
        int col = (rand() % 10) + 1;
        current_array_boxes[i][0] = rand() % (RESOLUTION_X-BOX_LEN);
        current_array_boxes[i][1] = rand() % (RESOLUTION_Y-BOX_LEN);
        current_array_boxes[i][2] = rand() % 2 * 2 - 1;
        current_array_boxes[i][3] = rand() % 2 * 2 - 1;
        current_array_boxes[i][4] = colors[col];
    }
    for (i = 0; i < NUM_BOXES; i++){
        prev_array_boxes[i][0] = current_array_boxes[i][1];
        prev_array_boxes[i][1] = current_array_boxes[i][1];
        prev_array_boxes[i][2] = 0;
        prev_array_boxes[i][3] = 0;
        prev_array_boxes[i][4] = 0x0000;
    }
    for (i = 0; i < NUM_BOXES; i++){
        new_prev_array_boxes[i][0] = current_array_boxes[i][1];
        new_prev_array_boxes[i][1] = current_array_boxes[i][1];
        new_prev_array_boxes[i][2] = 0;
        new_prev_array_boxes[i][3] = 0;
        new_prev_array_boxes[i][4] = 0x0000;
    }


    while (1)
    {
        /* Erase any boxes and lines that were drawn in the last iteration */
        draw_box(prev_array_boxes);
        draw_box(current_array_boxes);
        int i;
        //update with the previous frame locations
        for (i = 0; i < NUM_BOXES; i++) {
            prev_array_boxes[i][0] = new_prev_array_boxes[i][0];
            prev_array_boxes[i][1] = new_prev_array_boxes[i][1];
        } //update with current fram locations
        for (i = 0; i < NUM_BOXES; i++) {
            new_prev_array_boxes[i][0] = current_array_boxes[i][0];
            new_prev_array_boxes[i][1] = current_array_boxes[i][1];
        }

        for (i = 0; i < NUM_BOXES; i++) {
            if (current_array_boxes[i][0] == 0 || current_array_boxes[i][0] == (319- BOX_LEN)) {
                current_array_boxes[i][2] *= -1;
            }

            if (current_array_boxes[i][1] == 0 || current_array_boxes[i][1] == (239- BOX_LEN)) {
                current_array_boxes[i][3] *= -1;
            }
            current_array_boxes[i][0] += current_array_boxes[i][2];
            current_array_boxes[i][1] += current_array_boxes[i][3];
        }

        // code for drawing the boxes and lines (not shown)
        // code for updating the locations of boxes (not shown)

        wait_for_vsync(); // swap front and back buffers on VGA vertical sync
        pixel_buffer_start = *(pixel_ctrl_ptr + 1); // new back buffer
    }
}

// code for subroutines (not shown)
