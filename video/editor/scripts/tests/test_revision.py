import importlib.util
import array
import subprocess
import unittest
from pathlib import Path

path=Path(__file__).resolve().parents[1]/'render_revised.py'
spec=importlib.util.spec_from_file_location('render_revised',path)
revision=importlib.util.module_from_spec(spec)
spec.loader.exec_module(revision)


class RevisionTest(unittest.TestCase):
    def test_half_each_gap_without_cutting_narration_or_outro(self):
        voices=[{'id':'a','start':0,'end':2},{'id':'b','start':6,'end':8}]
        cuts=revision.removals_for(voices,15*60,13*60)
        self.assertEqual(cuts,[(180,300),(570,780)])
        self.assertEqual(revision.map_frame(15*60,cuts),570)
        self.assertEqual(revision.map_frame(6*60,cuts),240)
        for start,end in cuts:
            for voice in voices:
                self.assertFalse(start<voice['end']*60 and end>voice['start']*60)
        self.assertLessEqual(cuts[-1][1],13*60)

    def test_subtitles_remove_punctuation_without_losing_decimal_meaning(self):
        self.assertEqual(revision.subtitle_text('《Saltline》，使用 Three.js 5.2；约 0.56。'),
                         'Saltline 使用 Three js 5点2 约 0点56')

    def test_overlapping_voice_is_rejected(self):
        with self.assertRaises(ValueError):
            revision.removals_for([{'id':'a','start':0,'end':3},{'id':'b','start':2,'end':4}],600,550)

    def test_audio_cut_keeps_other_samples_and_fades_the_join(self):
        filters=revision.audio_filter_for([(60,120)],'between(n,60,119)')
        raw=subprocess.check_output(['ffmpeg','-v','error','-f','lavfi','-i','aevalsrc=0.5:s=48000:d=4',
                                     '-af',filters,'-f','f32le','-'])
        samples=array.array('f');samples.frombytes(raw)
        self.assertEqual(len(samples),3*48000)
        self.assertAlmostEqual(samples[5000],.5,places=3)
        self.assertAlmostEqual(samples[70000],.5,places=3)
        self.assertLess(samples[47999],.01)
        self.assertLess(samples[48000],.01)


if __name__=='__main__':unittest.main()
