from platform_cli import ROOT, GAME, toolchain, run_process
print(run_process([toolchain()['godot'],'--path',str(GAME),'--script','res://../tools/review_beta_sword.gd'],rendered=True,log='beta-sword-review.log'))
