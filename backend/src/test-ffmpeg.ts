const ffmpeg = require('fluent-ffmpeg');

const ffmpegPath = require('ffmpeg-static');
const path = require('path');

async function testDownload() {
  console.log('Starting FFmpeg test...');
  console.log(`FFmpeg path: ${ffmpegPath}`);

  if (ffmpegPath) {
    ffmpeg.setFfmpegPath(ffmpegPath);
  } else {
    console.error('FFmpeg static binary not found!');
    return;
  }

  // Use a reliable public HLS stream for testing (Big Buck Bunny)
  // https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8
  // Short URL to avoid issues
  const url = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
  const outputPath = path.join(__dirname, '..', 'test-output.mp4');

  console.log(`Downloading from: ${url}`);
  console.log(`Saving to: ${outputPath}`);

  return new Promise((resolve, reject) => {
    ffmpeg(url)
      .outputOptions('-c copy')
      .outputOptions('-bsf:a', 'aac_adtstoasc')
      .output(outputPath)
      .on('start', (commandLine) => {
        console.log(`Spawned Ffmpeg with command: ${commandLine}`);
      })
      .on('progress', (progress) => {
        if (progress.percent) {
          console.log(`Processing: ${Math.round(progress.percent)}% done`);
        } else {
          console.log('Processing...', progress);
        }
      })
      .on('error', (err) => {
        console.error('An error occurred: ' + err.message);
        reject(err);
      })
      .on('end', () => {
        console.log('Processing finished successfully!');
        resolve(true);
      })
      .run();
  });
}

testDownload().catch(console.error);
