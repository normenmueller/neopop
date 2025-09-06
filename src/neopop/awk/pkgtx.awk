# pkgtx.awk — split Cypher input into chunks with ≤ max_stmt statements each.
# - Counts ';' only outside of strings (' " `) and comments (//, /* */)
# - Preserves original content verbatim (except CRLF→LF normalization)
# - Writes chunk files into tmpdir as: chunk.000001.cypher, ...
# - Prints each chunk's absolute path on stdout when the chunk is closed.
#
# Required -v variables:
#   tmpdir   : target directory for chunks
#   max_stmt : integer ≥ 1 (number of statements per chunk)

BEGIN{
  if (max_stmt < 1) { exit 2 }

  in_sq=0; in_dq=0; in_bt=0; esc=0;      # strings: ' " `
  in_slc=0; in_blc=0;                     # comments: //   /* ... */
  stmt_count=0; chunk_idx=0;
  cf=""; prev="";

  SQ=sprintf("%c",39); DQ=sprintf("%c",34); BT=sprintf("%c",96);
}

function open_new_chunk(){
  chunk_idx++
  cf = tmpdir "/chunk." sprintf("%06d", chunk_idx) ".cypher"
  # small progress to stderr is caller's job; we just create files
  stmt_count = 0
}

function close_current_chunk(){
  if (cf != "") {
    print cf
    close(cf)
    cf = ""
  }
}

{
  line = $0
  gsub(/\r/, "", line)     # normalize CRLF -> LF
  n = length(line)

  for (i=1; i<=n; i++){
    ch = substr(line, i, 1)

    # --- State machine ---
    if (in_slc) {
      # single-line comment ends at line end
    } else if (in_blc) {
      if (prev=="*" && ch=="/") in_blc=0
    } else {
      if (esc) {
        esc=0
      } else if (in_sq) {
        if (ch==SQ) in_sq=0
        if (ch=="\\") esc=1
      } else if (in_dq) {
        if (ch==DQ) in_dq=0
        if (ch=="\\") esc=1
      } else if (in_bt) {
        if (ch==BT) in_bt=0
        if (ch=="\\") esc=1
      } else {
        # code region
        if (prev=="/" && ch=="/") {
          in_slc=1
        } else if (prev=="/" && ch=="*") {
          in_blc=1
        } else {
          if (ch==SQ) in_sq=1
          else if (ch==DQ) in_dq=1
          else if (ch==BT) in_bt=1
        }
      }
    }

    if (cf=="") open_new_chunk()
    printf "%s", ch >> cf

    # semicolon only counts outside of strings/comments
    if (ch==";" && !in_sq && !in_dq && !in_bt && !in_slc && !in_blc) {
      stmt_count++
      if (stmt_count >= max_stmt) {
        printf "\n" >> cf
        close_current_chunk()
      }
    }

    prev = ch
  }

  # end of line: single-line comment closes here
  if (in_slc) in_slc=0

  # keep original newlines
  if (cf!="") printf "\n" >> cf
}

END{
  # flush last open chunk (if any)
  close_current_chunk()
}

