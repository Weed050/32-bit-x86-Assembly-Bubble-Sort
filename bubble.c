#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <string.h>

void bubble_sort(int *arr, int len) {
    for (int i = 0; i < len - 1; i++) {
        for (int j = 0; j < len - 1 - i; j++) {
            if (arr[j] > arr[j + 1]) {
                int tmp = arr[j];
                arr[j] = arr[j + 1];
                arr[j + 1] = tmp;
            }
        }
    }
}

void clear_input() {
    int c;
    while ((c = getchar()) != '\n');
}

int main() {
    int capacity = 2;
    int count = 0;
    int *arr = malloc(capacity * sizeof(int));

start:
    count = 0;
    printf("numbers: ");

    while (1) {
        int n, result;
        result = scanf("%d", &n);

        if (result != 1) {
            clear_input();
            goto start;
        }

        if (count >= capacity) {
            capacity *= 2;
            int *new_arr = realloc(arr, capacity * sizeof(int));
            if (!new_arr) {
                free(arr);
                return 1;
            }
            arr = new_arr;
        }

        arr[count] = n;
        count++;

        int c = getchar(); 
        if (c == '\n') {
            break;
        } else if (c != ' ') {
            clear_input();
            goto start;
        }
    }

    if (count < 2) {
        goto start;
    }

    bubble_sort(arr, count);

    printf("sorted: ");
    for (int i = 0; i < count; i++) {
        printf("%d ", arr[i]);
    }
    printf("\n");

    free(arr);
    return 0;
}