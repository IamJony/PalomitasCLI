#!/bin/bash
# Interfaz CLI Palomitas by IamJony

# Configuración
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
SEARCH_SCRIPT="$SCRIPT_DIR/search.sh"
IFRAME_SCRIPT="$SCRIPT_DIR/iframe.sh"
EMBED_SCRIPT="$SCRIPT_DIR/embed.sh"

# Cargar configuración si existe
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    # Colores básicos
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    MAGENTA='\033[0;35m'
    NC='\033[0m'
fi

# Variables globales
SEARCH_RESULTS=""
SELECTED_MOVIE=""
MOVIE_URL=""
PLAYER_URL=""
STREAM_URL=""

# Limpiar pantalla
clear_screen() {
    printf "\033c"
}

# Mostrar banner
show_banner() {
    clear_screen
    printf "${CYAN}"
    printf "╔══════════════════════════════════════════╗\n"
    printf "║     ${YELLOW}Palomitas BY IamJony v1.0${CYAN}          ║\n"
    printf "║   https://github.com/IamJony             ║\n"
    printf "║    Buscar → Extraer → Reproducir         ║\n"
    printf "╚══════════════════════════════════════════╝\n"
    printf "${NC}"
}

# Mostrar menú principal
show_main_menu() {
    printf "${CYAN}=== MENÚ PRINCIPAL ===${NC}\n"
    printf "\n"
    printf "  1) ${GREEN}Buscar películas${NC}\n"
    printf "  2) ${BLUE}Reproducir desde URL${NC}\n"
    printf "  3) ${YELLOW}Limpiar archivos${NC}\n"
    printf "  0) ${RED}Salir${NC}\n"
    printf "\n"
    printf "Selecciona una opción: "
}

# Buscar películas
search_movies() {
    show_banner
    printf "${CYAN}=== BUSCAR PELÍCULAS ===${NC}\n"
    printf "\n"
    
    if [ $# -eq 0 ]; then
        printf "¿Qué película buscas?: "
        read -r query
    else
        query="$*"
    fi
    
    if [ -z "$query" ]; then
        printf "${RED}✗ No se ingresó término de búsqueda${NC}\n"
        sleep 2
        return
    fi
    
    printf "\n${YELLOW}Buscando: $query${NC}\n"
    printf "\n"
    
    # Ejecutar búsqueda
    if [ -f "$SEARCH_SCRIPT" ]; then
        bash "$SEARCH_SCRIPT" "$query"
    else
        printf "${RED}✗ Error: No se encuentra search.sh${NC}\n"
        sleep 2
        return
    fi
    
    if [ ! -f "buscar.json" ]; then
        printf "${RED}✗ No se encontraron resultados${NC}\n"
        sleep 2
        return
    fi
    
    # Procesar resultados
    process_search_results
}

# Procesar y mostrar resultados de búsqueda
process_search_results() {
    local results=()
    local titles=()
    local urls=()
    local count=0
    
    # Extraer datos del JSON
    if command -v jq &> /dev/null; then
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                id=$(echo "$line" | cut -d'|' -f1)
                title=$(echo "$line" | cut -d'|' -f2)
                url=$(echo "$line" | cut -d'|' -f3)
                
                results+=("$id|$title|$url")
                titles+=("$title")
                urls+=("$url")
                ((count++))
            fi
        done < <(jq -r 'to_entries[] | "\(.key)|\(.value.title)|\(.value.url)"' buscar.json 2>/dev/null)
    else
        printf "${RED}✗ Necesitas instalar jq para procesar resultados${NC}\n"
        printf "Instala con: apt install jq  o  brew install jq\n"
        sleep 3
        return
    fi
    
    if [ $count -eq 0 ]; then
        printf "${RED}✗ No se encontraron resultados${NC}\n"
        sleep 2
        return
    fi
    
    SEARCH_RESULTS=("${results[@]}")
    show_movie_selection "$count" "${titles[@]}"
}

# Mostrar selección de películas
show_movie_selection() {
    local count=$1
    shift
    local titles=("$@")
    
    printf "${GREEN}✓ Encontradas $count películas:${NC}\n"
    printf "\n"
    
    # Mostrar lista numerada
    for i in "${!titles[@]}"; do
        printf "  ${CYAN}%2d)${NC} %s\n" $((i+1)) "${titles[$i]}"
    done
    
    printf "\n"
    printf "  ${YELLOW}0)${NC} Volver al menú principal\n"
    printf "\n"
    
    while true; do
        printf "Selecciona una película (1-$count): "
        read -r choice
        
        if [[ "$choice" == "0" ]]; then
            return
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
            select_movie $((choice-1))
            break
        else
            printf "${RED}✗ Opción inválida. Intenta de nuevo.${NC}\n"
        fi
    done
}

# Seleccionar película
select_movie() {
    local index=$1
    local selected="${SEARCH_RESULTS[$index]}"
    
    SELECTED_MOVIE=$(echo "$selected" | cut -d'|' -f2)
    MOVIE_URL=$(echo "$selected" | cut -d'|' -f3)
    
    printf "\n${GREEN}✓ Seleccionada: $SELECTED_MOVIE${NC}\n"
   # printf "${BLUE}URL: $MOVIE_URL${NC}\n"
    printf "\n"
    
    process_movie
}

# Procesar película seleccionada
process_movie() {
    printf "${YELLOW}Extrayendo iframe...${NC}\n"
    
    # Extraer iframe
    if [ -f "$IFRAME_SCRIPT" ]; then
        bash "$IFRAME_SCRIPT" "$MOVIE_URL"
    else
        printf "${RED}✗ Error: No se encuentra iframe.sh${NC}\n"
        sleep 2
        return
    fi
    
    if [ ! -f "peli.json" ]; then
        printf "${RED}✗ No se pudo extraer el iframe${NC}\n"
        sleep 2
        return
    fi
    
    # Obtener URL del player
    if command -v jq &> /dev/null; then
        PLAYER_URL=$(jq -r '.embed_url // .url // ""' peli.json 2>/dev/null)
        
        if [ -z "$PLAYER_URL" ] || [ "$PLAYER_URL" == "null" ]; then
            PLAYER_URL=$(grep -o '"embed_url":"[^"]*"' peli.json | head -1 | cut -d'"' -f4)
        fi
    else
        PLAYER_URL=$(grep -o '"embed_url":"[^"]*"' peli.json | head -1 | cut -d'"' -f4)
    fi
    
    if [ -z "$PLAYER_URL" ]; then
        printf "${RED}✗ No se pudo obtener URL del player${NC}\n"
        printf "Revisa el archivo peli.json manualmente\n"
        sleep 3
        return
    fi
    
    printf "${GREEN}✓ Player URL: $PLAYER_URL${NC}\n"
    printf "\n"
    
    extract_stream
}

# Extraer stream M3U8
extract_stream() {
    printf "${YELLOW}Extrayendo stream...${NC}\n"
    
    # Extraer embed
    if [ -f "$EMBED_SCRIPT" ]; then
        bash "$EMBED_SCRIPT" "$PLAYER_URL" "$MOVIE_URL"
    else
        printf "${RED}✗ Error: No se encuentra embed.sh${NC}\n"
        sleep 2
        return
    fi
    
    if [ ! -f "output.json" ]; then
        printf "${RED}✗ No se pudo extraer el stream${NC}\n"
        sleep 2
        return
    fi
    
    # Obtener URL del stream
    if command -v jq &> /dev/null; then
        STREAM_URL=$(jq -r '.video' output.json 2>/dev/null)
        STREAM_TYPE=$(jq -r '.type' output.json 2>/dev/null)
    else
        STREAM_URL=$(grep -o '"video":"[^"]*"' output.json | head -1 | cut -d'"' -f4)
        STREAM_TYPE=$(grep -o '"type":"[^"]*"' output.json | head -1 | cut -d'"' -f4)
    fi
    
    if [ -z "$STREAM_URL" ] || [ "$STREAM_URL" == "null" ]; then
        printf "${RED}✗ No se pudo obtener URL del stream${NC}\n"
        printf "Revisa el archivo output.json manualmente\n"
        sleep 3
        return
    fi
    
    printf "${GREEN}✓ Stream extraído correctamente!${NC}\n"
    printf "${BLUE}Tipo: $STREAM_TYPE${NC}\n"
    printf "\n"
    
    play_stream
}

# Reproducir stream
play_stream() {
    printf "${CYAN}=== REPRODUCIR ===${NC}\n"
    printf "\n"
    printf "Película: $SELECTED_MOVIE\n"
    printf "URL: $STREAM_URL\n"
    printf "\n"
    printf "Opciones:\n"
    printf "  1) ${GREEN}Reproducir con mpv${NC}\n"
    printf "  2) ${BLUE}Descargar stream${NC}\n"
    printf "  3) ${YELLOW}Volver al menú${NC}\n"
    printf "\n"
    
   while true; do
    printf "Selecciona opción (1-3): "
    read -r choice
    
    case $choice in
        1)
            printf "\n${GREEN}▶ Iniciando reproducción con mpv...${NC}\n"
            printf "${YELLOW}Presiona 'q' para salir del reproductor${NC}\n"
            mpv --referrer="https://barmonrey.com" "$STREAM_URL"
            ;;
        2)
            echo "OPCION AUN NO DISPONIBLE"
            ;;
        3)
            return  
            ;;
        *) 
            clear
            play_stream
            ;;
    esac
done
}

# Reproducir desde URL directa
play_from_url() {
    show_banner
    printf "${CYAN}=== REPRODUCIR DESDE URL ===${NC}\n"
    printf "\n"
    
    printf "Formato de URL: https://xxxxx.com/pelicula/nombre-pelicula/\n"
    printf "Ingresa la URL: "
    read -r url
    
    if [ -z "$url" ]; then
        printf "${RED}✗ No se ingresó URL${NC}\n"
        sleep 2
        return
    fi
    
    MOVIE_URL="$url"
    SELECTED_MOVIE="Película desde URL"
    
    printf "\n${YELLOW}Procesando: $url${NC}\n"
    process_movie
}

# Limpiar archivos
cleanup_files() {
    show_banner
    printf "${CYAN}=== LIMPIAR ARCHIVOS ===${NC}\n"
    printf "\n"
    
    rm -f buscar.json peli.json output.json 2>/dev/null
    
    printf "${GREEN}✓ Archivos temporales eliminados${NC}\n"
    sleep 2
}

# Verificar dependencias
check_dependencies() {
    local missing=()
    
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        printf "${RED}✗ Faltan dependencias:${NC}\n"
        for dep in "${missing[@]}"; do
            printf "  - $dep\n"
        done
        printf "\n"
        printf "Instala con:\n"
        printf "  Ubuntu/Debian: sudo apt install ${missing[*]}\n"
        printf "  macOS: brew install ${missing[*]}\n"
        printf "\n"
        read -p "Presiona Enter para continuar de todos modos..."
    fi
}

# Modo de línea de comandos
command_line_mode() {
    case "$1" in
        search|s)
            shift
            search_movies "$@"
            
            # Si hay argumentos adicionales, intentar reproducir automáticamente
            if [ -n "$MOVIE_URL" ] && [ "$2" == "--play" ]; then
                process_movie
                if [ -n "$STREAM_URL" ]; then
                    if command -v mpv &> /dev/null; then
                        printf "\n${GREEN}▶ Iniciando reproducción automática...${NC}\n"
                        mpv --referrer="https://barmonrey.com" "$STREAM_URL"
                    fi
                fi
            fi
            ;;
        play|p)
            shift
            if [ $# -eq 0 ]; then
                play_from_url
            else
                MOVIE_URL="$1"
                SELECTED_MOVIE="Película desde CLI"
                process_movie
                if [ -n "$STREAM_URL" ] && command -v mpv &> /dev/null; then
                   mpv --referrer="https://barmonrey.com" "$STREAM_URL"
                fi
            fi
            ;;
        clean|c)
            cleanup_files
            ;;
        help|h)
            show_help
            ;;
        *)
            printf "${RED}Comando desconocido: $1${NC}\n"
            show_help
            exit 1
            ;;
    esac
    exit 0
}

# Mostrar ayuda
show_help() {
    show_banner
    printf "${CYAN}=== AYUDA ===${NC}\n"
    printf "\n"
    printf "Modo interactivo:\n"
    printf "  $0\n"
    printf "\n"
    printf "Modo línea de comandos:\n"
    printf "  $0 search <término>          Buscar películas\n"
    printf "  $0 search <término> --play   Buscar y reproducir primera\n"
    printf "  $0 play <url>                Reproducir desde URL\n"
    printf "  $0 clean                     Limpiar archivos\n"
    printf "\n"
    printf "Alias:\n"
    printf "  s, search                    Buscar\n"
    printf "  p, play                      Reproducir\n"
    printf "  c, clean                     Limpiar\n"
    printf "\n"
}

# Programa principal
main() {
    # Verificar si hay argumentos para modo CLI
    if [ $# -gt 0 ]; then
        command_line_mode "$@"
    fi
    
    # Verificar dependencias
    check_dependencies
    
    # Modo interactivo
    while true; do
        show_banner
        show_main_menu
        
        read -r choice
        
        case $choice in
            1)
                search_movies
                ;;
            2)
                play_from_url
                ;;
            3)
                cleanup_files
                ;;
            0)
                printf "\n${GREEN}¡Hasta luego!${NC}\n"
                printf "\n"
                exit 0
                ;;
            *)
                printf "\n${RED}✗ Opción inválida${NC}\n"
                sleep 1
                ;;
        esac
    done
}

# Manejar Ctrl+C
trap 'printf "\n\n${RED}✗ Interrumpido por el usuario${NC}\n"; exit 1' INT

# Ejecutar
main "$@"
