from platform_cli import ROOT,GAME,toolchain,run_process
print(run_process([toolchain()['godot'],'--path',str(GAME),'--script','res://../tools/review_beta_wolf.gd'],rendered=True,log='beta-wolf-review.log'))
