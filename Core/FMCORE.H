#ifndef FMCORE_H
#define FMCORE_H

/* The single-instance core has no dependency on Windows or audio delivery. */
#ifdef __cplusplus
extern "C" {
#endif
void fmReset(long sampleRate);
void fmQuickReset(void);
void fmStopPlayback(void);
void fmShort(unsigned char status, unsigned char data1, unsigned char data2);
void fmLong(unsigned char *data, unsigned size);
void fmRender(short *pcm, unsigned frames);
#ifdef __cplusplus
}
#endif
#endif
