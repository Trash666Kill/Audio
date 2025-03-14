#!/bin/bash

# Configurable variables (defaults)
ACODEC="pcm_s24le"          # Audio codec for WAV intermediate file
AR="176400"                 # Sample rate
MAP_METADATA="0"            # Metadata mapping
LOUDNORM_I="-18"            # Integrated loudness target (LUFS) - alterado de -16 para -18
LOUDNORM_TP="-1"            # True peak limit (dBTP)
LOUDNORM_LRA="12"           # Loudness range (LU) - alterado de 11 para 12
RESAMPLER="soxr"            # Resampler engine (soxr = SoX Resampler, swr = FFmpeg's default)
PRECISION="28"              # Resampler precision (for soxr, 16-32 bits, 28 is very high quality)
CHEBY="1"                   # Enable Chebyshev mode for soxr (1 = yes, 0 = no)
AF="aresample=resampler=$RESAMPLER:precision=$PRECISION:cheby=$CHEBY,loudnorm=I=$LOUDNORM_I:TP=$LOUDNORM_TP:LRA=$LOUDNORM_LRA"  # Audio filter (padrão atualizado)
LOUDNORM_LINEAR="false"     # Use linear (one-pass) loudness normalization (true) or two-pass (false)
USE_VOLUME="false"          # Flag to use volume instead of loudnorm (default: false)
VOLUME_VALUE="0dB"          # Default volume value (only used if --volume is specified)
ENABLE_SPECTROGRAM="false"  # Enable spectrogram generation (true/false)
SPECTROGRAM_SIZE="1920x1080"  # Default spectrogram resolution (width x height)
SPECTROGRAM_MODE="combined"  # Default spectrogram mode (combined or separate)
OUTPUT_FORMAT="wav"         # Output format: wav, wavpack, or flac
WAVPACK_COMPRESSION="0"     # WavPack compression level (0-6)
FLAC_COMPRESSION="0"        # FLAC compression level (0-12)
OVERWRITE="true"            # Overwrite existing files by default (true/false)
PARALLEL_JOBS=2             # Number of parallel jobs (default: 2)
WORKING_DIR="$(pwd)"        # Default to current directory

# Function to normalize paths (remove double slashes)
normalize_path() {
    echo "$1" | sed 's|//|/|g'
}

# Function to validate resolution format (e.g., "1920x1080")
validate_resolution() {
    if [[ "$1" =~ ^[0-9]+x[0-9]+$ ]]; then
        return 0
    else
        echo "Error: Spectrogram resolution must be in the format 'width x height' (e.g., 1920x1080)"
        exit 1
    fi
}

# Function to validate spectrogram mode
validate_spectrogram_mode() {
    case "$1" in
        "combined"|"separate")
            return 0
            ;;
        *)
            echo "Error: Invalid spectrogram mode '$1'. Valid options: combined, separate"
            exit 1
            ;;
    esac
}

# Function to validate volume value (e.g., "6dB", "-3dB")
validate_volume() {
    if [[ "$1" =~ ^-?[0-9]+(\.[0-9]+)?dB$ ]]; then
        return 0
    else
        echo "Error: Volume must be in the format 'XdB' or '-XdB' (e.g., '6dB', '-3dB')"
        exit 1
    fi
}

# Function to display README
show_help() {
    cat << 'EOF'
README: PureTone - DSD to High-Quality Audio Converter

PureTone converts DSD (.dsf) audio files to WAV, WavPack, or FLAC formats, preserving maximum audio fidelity. It uses ffmpeg to process files in parallel with GNU Parallel, extract metadata, and optionally generate spectrogram images.

### How it Works
1. **Input**: Accepts a single .dsf file or scans the specified/current directory for .dsf files or subdirectories.
2. **Metadata Extraction**: Uses ffprobe to extract artist and album metadata.
3. **Conversion Flow**: Converts DSD to WAV, then to the final format, using parallel processing for directories.
4. **Output**: Files are saved in 'wv/', 'wvpk/', or 'flac/' subdirectories relative to the input directory.
5. **Logging**: Details (ffmpeg output and conversion summary) saved in log.txt per directory.
6. **Spectrogram (Optional)**: Generates spectrogram images for output files if enabled, saved in 'wv/spectrogram/', etc.

### Usage
- Save as `puretone`, make executable: `chmod +x puretone`.
- Run: `./puretone [format] [options] [path/to/directory | path/to/file.dsf]`
  - The directory or file path must be the last argument.
  - Examples:
    - `./puretone flac --volume 6dB /path/to/music`
    - `./puretone wavpack --skip-existing --compression-level 6 --spectrogram 1920x1080 separate 'file.dsf'`
    - `./puretone --parallel 4 /path/to/dsd`

### Configurable Parameters
- **ACODEC**: Default: "pcm_s24le" (24-bit PCM).
- **AR**: Default: "176400" (176.4 kHz).
- **MAP_METADATA**: Default: "0" (copy all metadata).
- **LOUDNORM_I**: Integrated loudness (LUFS). Default: "-18".
- **LOUDNORM_TP**: True peak (dBTP). Default: "-1".
- **LOUDNORM_LRA**: Loudness range (LU). Default: "12".
- **RESAMPLER**: Resampler engine. Default: "soxr".
- **PRECISION**: Resampler precision (for soxr). Default: "28".
- **CHEBY**: Chebyshev mode for soxr. Default: "1".
- **LOUDNORM_LINEAR**: One-pass (true) or two-pass (false) loudness normalization. Default: "false".
- **ENABLE_SPECTROGRAM**: Spectrogram generation (true/false). Default: "false".
- **SPECTROGRAM_SIZE**: Spectrogram resolution (width x height). Default: "1920x1080".
- **SPECTROGRAM_MODE**: Spectrogram mode (combined or separate). Default: "combined".
- **OUTPUT_FORMAT**: "wav", "wavpack", "flac". Default: "wav".
- **WAVPACK_COMPRESSION**: 0-6. Default: "0".
- **FLAC_COMPRESSION**: 0-12. Default: "0".
- **OVERWRITE**: Overwrite files (true/false). Default: "true".
- **PARALLEL_JOBS**: Number of parallel jobs. Default: 2.

### Command-Line Options
- `<format>`: Output format: "wav", "wavpack", or "flac" (default: "wav").
- `--codec <value>`: Set audio codec (e.g., "pcm_s24le").
- `--sample-rate <value>`: Set sample rate (e.g., "176400").
- `--map-metadata <value>`: Set metadata mapping (e.g., "0").
- `--loudnorm-I <value>`: Set integrated loudness in LUFS (e.g., -14).
- `--loudnorm-TP <value>`: Set true peak in dBTP (e.g., -2).
- `--loudnorm-LRA <value>`: Set loudness range in LU (e.g., 9).
- `--volume <value>`: Set volume adjustment in dB (e.g., "6dB", "-3dB") instead of loudnorm.
- `--resampler <value>`: Set resampler engine (e.g., "soxr" or "swr").
- `--precision <value>`: Set resampler precision (e.g., "28", for soxr only).
- `--cheby <0|1>`: Enable/disable Chebyshev mode for soxr (1 = yes, 0 = no).
- `--loudnorm-linear <true|false>`: Use one-pass (true) or two-pass (false) loudness normalization.
- `--spectrogram [width x height] [mode]`: Enable spectrogram generation.
- `--compression-level <value>`: Compression level for WavPack (0-6) or FLAC (0-12).
- `--skip-existing`: Skip existing output files instead of overwriting.
- `--parallel <number>`: Set number of parallel jobs (e.g., 4).
- `--help`: Display this help message.
- `path/to/directory | path/to/file.dsf`: Path to process (must be last argument; required).

### Notes
- `--volume` and loudnorm options (--loudnorm-I, --loudnorm-TP, --loudnorm-LRA) cannot be used together.
EOF
    exit 0
}

# Check if no arguments are provided
if [ $# -eq 0 ]; then
    echo "Error: No arguments provided. Please specify a format, options, or directory/file path."
    echo "Usage: $0 [format] [options] [path/to/directory | path/to/file.dsf]"
    echo "Run '$0 --help' for more information."
    exit 1
fi

# Check for --help
[ "$1" = "--help" ] && show_help

# Variables for tracking
SKIP_EXISTING="false"
declare -i overwritten=0 skipped=0
TEMP_LOG="/tmp/puretone_$$_results.log"
> "$TEMP_LOG"  # Initialize temporary log file

# Flags to track if loudnorm options are used
LOUDNORM_I_USED="false"
LOUDNORM_TP_USED="false"
LOUDNORM_LRA_USED="false"

# Check for realpath dependency
command -v realpath >/dev/null || { echo "Error: realpath not found. Install with 'apt install coreutils'."; exit 1; }

# Parse arguments (directory or file must be last)
args=("$@")
last_arg="${args[-1]}"

# Check if last argument is a file or directory
if [[ "$last_arg" =~ \.dsf$ ]] && [ -f "$last_arg" ]; then
    INPUT_FILE=$(realpath "$last_arg")  # Arquivo individual
    WORKING_DIR=$(dirname "$INPUT_FILE")  # Diretório do arquivo
    unset 'args[-1]'  # Remove o arquivo dos args
elif [[ "$last_arg" =~ ^(/|./|../) ]] && [ -d "$last_arg" ]; then
    WORKING_DIR=$(realpath "$last_arg")  # Diretório especificado
    unset 'args[-1]'  # Remove o diretório dos args
else
    WORKING_DIR="$(pwd)"  # Default para o diretório atual
fi

# Parse remaining arguments
while [ ${#args[@]} -gt 0 ]; do
    arg="${args[0]}"
    case "$arg" in
        "wav"|"wavpack"|"flac")
            OUTPUT_FORMAT="$arg"
            ;;
        --codec) ACODEC="${args[1]}"; unset 'args[1]' ;;
        --sample-rate) [[ "${args[1]}" =~ ^[0-9]+$ ]] && AR="${args[1]}" || { echo "Error: --sample-rate requires a number"; exit 1; }; unset 'args[1]' ;;
        --map-metadata) MAP_METADATA="${args[1]}"; unset 'args[1]' ;;
        --loudnorm-I) LOUDNORM_I="${args[1]}"; LOUDNORM_I_USED="true"; unset 'args[1]' ;;
        --loudnorm-TP) LOUDNORM_TP="${args[1]}"; LOUDNORM_TP_USED="true"; unset 'args[1]' ;;
        --loudnorm-LRA) LOUDNORM_LRA="${args[1]}"; LOUDNORM_LRA_USED="true"; unset 'args[1]' ;;
        --volume) 
            validate_volume "${args[1]}"
            USE_VOLUME="true"
            VOLUME_VALUE="${args[1]}"
            unset 'args[1]'
            ;;
        --resampler) RESAMPLER="${args[1]}"; unset 'args[1]' ;;
        --precision) [[ "${args[1]}" =~ ^[0-9]+$ ]] && PRECISION="${args[1]}" || { echo "Error: --precision requires a number"; exit 1; }; unset 'args[1]' ;;
        --cheby) [[ "${args[1]}" =~ ^[0-1]$ ]] && CHEBY="${args[1]}" || { echo "Error: --cheby requires 0 or 1"; exit 1; }; unset 'args[1]' ;;
        --loudnorm-linear) [[ "${args[1]}" =~ ^(true|false)$ ]] && LOUDNORM_LINEAR="${args[1]}" || { echo "Error: --loudnorm-linear requires true/false"; exit 1; }; unset 'args[1]' ;;
        --spectrogram)
            ENABLE_SPECTROGRAM="true"
            if [ ${#args[@]} -gt 1 ] && [[ "${args[1]}" =~ ^[0-9]+x[0-9]+$ ]]; then
                validate_resolution "${args[1]}"
                SPECTROGRAM_SIZE="${args[1]}"
                unset 'args[1]'
                if [ ${#args[@]} -gt 1 ]; then
                    validate_spectrogram_mode "${args[1]}"
                    SPECTROGRAM_MODE="${args[1]}"
                    unset 'args[1]'
                fi
            fi
            ;;
        --compression-level)
            if [ "$OUTPUT_FORMAT" = "wav" ]; then
                echo "Warning: --compression-level not applicable to WAV format."
                unset 'args[1]'
            elif [ "$OUTPUT_FORMAT" = "wavpack" ]; then
                [[ "${args[1]}" =~ ^[0-6]$ ]] && WAVPACK_COMPRESSION="${args[1]}" || { echo "Error: WavPack compression 0-6"; exit 1; }
                unset 'args[1]'
            elif [ "$OUTPUT_FORMAT" = "flac" ]; then
                [[ "${args[1]}" =~ ^([0-9]|1[0-2])$ ]] && FLAC_COMPRESSION="${args[1]}" || { echo "Error: FLAC compression 0-12"; exit 1; }
                unset 'args[1]'
            fi
            ;;
        --skip-existing) SKIP_EXISTING="true" ;;
        --parallel) [[ "${args[1]}" =~ ^[0-9]+$ ]] && PARALLEL_JOBS="${args[1]}" || { echo "Error: --parallel requires a number"; exit 1; }; unset 'args[1]' ;;
        *) echo "Error: Unknown option or invalid format '$arg'. Directory or file must be the last argument."; exit 1 ;;
    esac
    unset 'args[0]'
    args=("${args[@]}")  # Reindex array
done

# Check for conflicts between --volume and loudnorm options
if [ "$USE_VOLUME" = "true" ] && { [ "$LOUDNORM_I_USED" = "true" ] || [ "$LOUDNORM_TP_USED" = "true" ] || [ "$LOUDNORM_LRA_USED" = "true" ]; }; then
    echo "Error: --volume cannot be used together with --loudnorm-I, --loudnorm-TP, or --loudnorm-LRA."
    echo "Use either --volume or loudnorm options, not both."
    exit 1
fi

# Check if AR is a multiple of 44100 Hz
if [ $((AR % 44100)) -ne 0 ]; then
    remainder=$((AR % 44100))
    quotient=$(echo "scale=4; $AR / 44100" | bc)
    echo "Warning: Sample rate $AR Hz is not an exact multiple of 44.1 kHz. This may introduce interpolation and reduce fidelity."
    echo "Calculation: $AR / 44100 = $quotient (remainder: $remainder), not an exact multiple."
    echo "Recommended values: 44100, 88200, 176400, 352800, 705600"
fi

# Adjust AF based on USE_VOLUME, LOUDNORM_LINEAR, and resampler settings
if [ "$USE_VOLUME" = "true" ]; then
    AF="aresample=resampler=$RESAMPLER:precision=$PRECISION:cheby=$CHEBY,volume=$VOLUME_VALUE"
else
    if [ "$LOUDNORM_LINEAR" = "true" ]; then
        AF="aresample=resampler=$RESAMPLER:precision=$PRECISION:cheby=$CHEBY,loudnorm=I=$LOUDNORM_I:TP=$LOUDNORM_TP:LRA=$LOUDNORM_LRA:linear=true"
    else
        AF="aresample=resampler=$RESAMPLER:precision=$PRECISION:cheby=$CHEBY,loudnorm=I=$LOUDNORM_I:TP=$LOUDNORM_TP:LRA=$LOUDNORM_LRA"
    fi
fi

# Set OUTPUT_BASE_DIR
case "$OUTPUT_FORMAT" in
    "wav") OUTPUT_BASE_DIR="wv" ;;
    "wavpack") OUTPUT_BASE_DIR="wvpk" ;;
    "flac") OUTPUT_BASE_DIR="flac" ;;
    *) echo "Error: Invalid OUTPUT_FORMAT"; exit 1 ;;
esac

# Export variables for parallel
export ACODEC AR MAP_METADATA AF LOUDNORM_LINEAR USE_VOLUME VOLUME_VALUE ENABLE_SPECTROGRAM SPECTROGRAM_SIZE SPECTROGRAM_MODE OUTPUT_FORMAT WAVPACK_COMPRESSION FLAC_COMPRESSION OVERWRITE SKIP_EXISTING OUTPUT_BASE_DIR TEMP_LOG WORKING_DIR

# Check dependencies
command -v ffmpeg >/dev/null || { echo "Error: ffmpeg not found. Install with 'apt install ffmpeg'."; exit 1; }
command -v ffprobe >/dev/null || { echo "Error: ffprobe not found."; exit 1; }
command -v parallel >/dev/null || { echo "Error: parallel not found. Install with 'apt install parallel'."; exit 1; }
command -v bc >/dev/null || { echo "Error: bc not found. Install with 'apt install bc'."; exit 1; }
echo "ffmpeg found. Version: $(ffmpeg -version | head -n 1)"
echo "parallel found. Version: $(parallel --version | head -n 1)"
echo "----------------------------------------"

# Record start time
START_TIME=$(date +%s)

# Display parameters
echo "Configured parameters:"
echo "  Working directory: $WORKING_DIR"
echo "  Audio codec (--codec): $ACODEC"
echo "  Sample rate (--sample-rate): $AR"
echo "  Metadata mapping (--map-metadata): $MAP_METADATA"
echo "  Audio filter (-af): $AF"
echo "  Loudnorm linear mode: $LOUDNORM_LINEAR (true = one-pass, false = two-pass, ignored if --volume is used)"
echo "  Use volume instead of loudnorm: $USE_VOLUME (value: $VOLUME_VALUE)"
echo "  Base output directory: $OUTPUT_BASE_DIR"
echo "  Spectrogram generation enabled: $ENABLE_SPECTROGRAM"
[ "$ENABLE_SPECTROGRAM" = "true" ] && echo "  Spectrogram resolution: $SPECTROGRAM_SIZE"
[ "$ENABLE_SPECTROGRAM" = "true" ] && echo "  Spectrogram mode: $SPECTROGRAM_MODE"
echo "  Output format: $OUTPUT_FORMAT"
echo "  Overwrite existing files: $OVERWRITE (overridden by --skip-existing: $SKIP_EXISTING)"
echo "  Parallel jobs: $PARALLEL_JOBS"
case "$OUTPUT_FORMAT" in
    "wavpack") echo "  WavPack compression level: $WAVPACK_COMPRESSION" ;;
    "flac") echo "  FLAC compression level: $FLAC_COMPRESSION" ;;
esac
echo ""

# Function to process a single file
process_file() {
    local input_file="$1"
    local dir=$(dirname "$input_file")
    local OUTPUT_DIR=$(normalize_path "$dir/$OUTPUT_BASE_DIR")
    local SPECTROGRAM_DIR=$(normalize_path "$OUTPUT_DIR/spectrogram")

    # Create OUTPUT_DIR
    if ! mkdir -p "$OUTPUT_DIR"; then
        echo "Error: Failed to create directory $OUTPUT_DIR" >&2
        echo "$dir:error" >> "$TEMP_LOG"
        return 1
    fi

    # Create SPECTROGRAM_DIR only if spectrogram is enabled
    if [ "$ENABLE_SPECTROGRAM" = "true" ]; then
        if ! mkdir -p "$SPECTROGRAM_DIR"; then
            echo "Error: Failed to create directory $SPECTROGRAM_DIR" >&2
            echo "$dir:error" >> "$TEMP_LOG"
            return 1
        fi
    fi

    # Extract metadata
    ARTIST=$(ffprobe -v quiet -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null || echo "Unknown Artist")
    ALBUM=$(ffprobe -v quiet -show_entries format_tags=album -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>/dev/null || echo "Unknown Album")

    # Define file names with absolute paths
    base_name=$(basename "$input_file" .dsf)
    wav_temp_file=$(normalize_path "$OUTPUT_DIR/${base_name}_temp.wav")
    case "$OUTPUT_FORMAT" in
        "wav") output_file=$(normalize_path "$OUTPUT_DIR/$base_name.wav") ;;
        "wavpack") output_file=$(normalize_path "$OUTPUT_DIR/$base_name.wv") ;;
        "flac") output_file=$(normalize_path "$OUTPUT_DIR/$base_name.flac") ;;
    esac
    spectrogram_file=$(normalize_path "$SPECTROGRAM_DIR/$base_name.png")

    # Check if output file exists
    if [ -e "$output_file" ]; then
        if [ "$SKIP_EXISTING" = "true" ]; then
            echo "File $output_file already exists. Skipping conversion of $input_file (--skip-existing enabled)."
            echo "$dir:skipped" >> "$TEMP_LOG"
            return 0
        elif [ "$OVERWRITE" = "true" ]; then
            echo "File $output_file already exists. Overwriting due to OVERWRITE=true."
            echo "$dir:overwritten" >> "$TEMP_LOG"
        fi
    else
        echo "$dir:converted" >> "$TEMP_LOG"
    fi

    log_file=$(normalize_path "$OUTPUT_DIR/log.txt")

    # Clear log file only for the first file in this run (using lock file)
    if [ ! -f "$OUTPUT_DIR/.processed" ]; then
        > "$log_file" || { echo "Error: Cannot write to $log_file" >&2; echo "$dir:error" >> "$TEMP_LOG"; return 1; }
        touch "$OUTPUT_DIR/.processed"
    fi

    # Convert DSD to WAV
    ffmpeg -i "$input_file" -acodec "$ACODEC" -ar "$AR" -map_metadata "$MAP_METADATA" -af "$AF" "$wav_temp_file" -y >> "$log_file" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error converting $input_file to intermediate WAV" >&2
        echo "Check $log_file for details" >&2
        rm -f "$wav_temp_file"
        echo "$dir:error" >> "$TEMP_LOG"
        return 1
    fi

    # Convert to final format
    case "$OUTPUT_FORMAT" in
        "wav") mv "$wav_temp_file" "$output_file" || { echo "Error moving $wav_temp_file to $output_file" >&2; echo "$dir:error" >> "$TEMP_LOG"; return 1; } ;;
        "wavpack") ffmpeg -i "$wav_temp_file" -acodec wavpack -compression_level "$WAVPACK_COMPRESSION" "$output_file" -y >> "$log_file" 2>&1 ;;
        "flac") ffmpeg -i "$wav_temp_file" -acodec flac -compression_level "$FLAC_COMPRESSION" "$output_file" -y >> "$log_file" 2>&1 ;;
    esac
    if [ $? -ne 0 ]; then
        echo "Error converting $input_file to $OUTPUT_FORMAT" >&2
        rm -f "$wav_temp_file"
        echo "$dir:error" >> "$TEMP_LOG"
        return 1
    fi
    rm -f "$wav_temp_file"

    # Verify output integrity
    if [ ! -s "$output_file" ]; then
        echo "Error: $output_file is empty" >&2
        echo "$dir:error" >> "$TEMP_LOG"
        return 1
    fi

    # Generate spectrogram if enabled
    if [ "$ENABLE_SPECTROGRAM" = "true" ]; then
        ffmpeg -i "$output_file" -lavfi "showspectrumpic=s=$SPECTROGRAM_SIZE:mode=$SPECTROGRAM_MODE" "$spectrogram_file" -y >> "$log_file" 2>&1
        if [ $? -ne 0 ]; then
            echo "Error generating spectrogram for $output_file" >&2
            echo "Check $log_file for details" >&2
            echo "$dir:error" >> "$TEMP_LOG"
            return 1
        fi
        echo "Generated spectrogram: $spectrogram_file"
    fi

    echo "Converted: $input_file -> $output_file"
    return 0
}

# Cleanup function for interruption
cleanup() {
    echo "Script interrupted. Cleaning up temporary files..."
    find "$WORKING_DIR" -name "*_temp.wav" -delete
    rm -f "$TEMP_LOG"
    exit 1
}
trap cleanup INT TERM

# Export the function for parallel
export -f process_file normalize_path

# Change to the working directory
cd "$WORKING_DIR" || { echo "Error: Cannot change to directory $WORKING_DIR"; exit 1; }

# Main logic
echo "Starting conversion..."
echo "----------------------------------------"

# Variables to track results
declare -A log_files file_counts
success=1

# If INPUT_FILE is set, process only that file
if [ -n "$INPUT_FILE" ]; then
    echo "Processing single file: $INPUT_FILE"
    process_file "$INPUT_FILE" || success=0
else
    # Check for .dsf files in current directory or subdirectories
    dsf_files_found=$(find . -maxdepth 1 -name "*.dsf" | wc -l)
    if [ "$dsf_files_found" -gt 0 ]; then
        echo "Processing directory: $WORKING_DIR"
        find . -maxdepth 1 -name "*.dsf" | parallel -j "$PARALLEL_JOBS" --line-buffer process_file || success=0
    else
        subdirs_with_dsf=$(find . -maxdepth 1 -type d -not -path . -exec sh -c 'find "{}" -maxdepth 1 -name "*.dsf" | grep -q . && echo "{}"' \; | sed 's|./||')
        if [ -n "$subdirs_with_dsf" ]; then
            echo "Converting all subdirectories with .dsf files in $WORKING_DIR:"
            echo "$subdirs_with_dsf"
            echo "----------------------------------------"
            echo "Warning: This will process all subdirectories listed above."
            read -p "Do you want to continue? (y/n): " response
            case "$response" in
                [Yy]*)
                    echo "Proceeding with conversion..."
                    echo "$subdirs_with_dsf" | while IFS= read -r subdir; do
                        echo "Processing subdirectory: $subdir"
                        find "$subdir" -maxdepth 1 -name "*.dsf" | parallel -j "$PARALLEL_JOBS" --line-buffer process_file || success=0
                    done
                    ;;
                [Nn]*)
                    echo "Aborting conversion."
                    rm -f "$TEMP_LOG"
                    exit 0
                    ;;
                *)
                    echo "Invalid response. Aborting conversion."
                    rm -f "$TEMP_LOG"
                    exit 1
                    ;;
            esac
        else
            echo "No .dsf files found in $WORKING_DIR or its subdirectories."
            rm -f "$TEMP_LOG"
            exit 1
        fi
    fi
fi

# Collect results from the temporary log
while IFS=':' read -r dir status; do
    case "$status" in
        "converted") ((file_counts["$dir"]++)) ;;
        "overwritten") ((file_counts["$dir"]++)); ((overwritten++)) ;;
        "skipped") ((skipped++)) ;;
        "error") success=0 ;;
    esac
    log_files["$dir"]=$(normalize_path "$dir/$OUTPUT_BASE_DIR/log.txt")
done < "$TEMP_LOG"
rm -f "$TEMP_LOG"

# Calculate elapsed time
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))

# Display results
if [ $success -eq 1 ]; then
    echo "Conversion completed successfully!"
else
    echo "Conversion completed with errors!"
fi
total_files=0
if [ ${#log_files[@]} -gt 0 ]; then
    echo "Details saved in the following log files:"
    for dir in "${!log_files[@]}"; do
        echo "  ${log_files[$dir]} (${file_counts[$dir]:-0} files converted)"
        ((total_files += ${file_counts[$dir]:-0}))
    done
    echo "Total files converted: $total_files"
    [ $overwritten -gt 0 ] && echo "Files overwritten: $overwritten"
    [ $skipped -gt 0 ] && echo "Files skipped: $skipped"
fi
[ "$ENABLE_SPECTROGRAM" = "true" ] && echo "Spectrograms saved in each output directory under spectrogram/ (e.g., $OUTPUT_BASE_DIR/spectrogram/output.png)."

echo "Elapsed time: $ELAPSED_TIME seconds"

# Append completion message to logs
for log_file in "${log_files[@]}"; do
    echo "" >> "$log_file"
    echo "----------------------------------------" >> "$log_file"
    [ $success -eq 1 ] && echo "Conversion completed on $(date)" >> "$log_file" || echo "Conversion completed with errors on $(date)" >> "$log_file"
    echo "Elapsed time: $ELAPSED_TIME seconds" >> "$log_file"
done

# Clean up processed markers
find "$WORKING_DIR" -name ".processed" -delete