import os
from src.utils.tensorboard import dummy_tb_write

def jobsetop(tb_write):
    print_jobset_env(tb_write)

def print_jobset_env(tb_write):
    jci = os.environ.get("JOB_COMPLETION_INDEX")
    print(f"job completion index: {jci}", )
    if tb_write:
        dummy_tb_write(f"From job_index {jci}")
