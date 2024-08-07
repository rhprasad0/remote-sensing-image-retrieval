
import argparse
import time
import yaml
import logging
import torch
import pickle
import os
from torch.utils.data import DataLoader
from model import build_model
from datasets import load_dataset
from datetime import datetime, timezone, timedelta
from pinecone import Pinecone
from dotenv import load_dotenv

load_dotenv()

output_path = os.getenv('OUTPUT_PATH', os.path.join('output', 'embeddings'))

def run_inference(cfg, args):
    # Create output dir (default: output_path/<model>/<dataset>/)
    output_dir = args.output_dir or os.path.join(output_path,
                                                 cfg['model']['name'],
                                                 f"{cfg['dataset']['name']}{args.input_size or ''}")
    # assert not os.path.isdir(output_dir) or len(os.listdir(output_dir)) == 0, \
    #     (f"Output directory already exists and is not empty ({output_dir}). "
    #      f"Specify the directory with --output_dir <path/to/output_dir>")
    # os.makedirs(output_dir, exist_ok=True)

    logging.info(f"Running inference with model {cfg['model']['name']} for dataset {cfg['dataset']['name']}.")
    # Init dataset
    dataset = load_dataset(cfg)

    # Init data loader
    data_loader = DataLoader(
        dataset,
        **cfg['dataloader'],
    )
    logging.info('DataLoader initialized')

    if torch.cuda.is_available():
        device = torch.device('cuda')
    else:
        device = torch.device('cpu')

    # Init model
    model = build_model(cfg)
    model = model.to(device)
    model.eval()
    logging.info('Model loaded')

    embedding_tuples = []
    time_start = time.time()
    num_batches = len(data_loader)
    i = 0

    # Run inference
    logging.info(f'Starting inference on {len(dataset)} samples')
    for batch in data_loader:
        # Load input
        input = batch['image']
        names = batch['name']
        
        input = input.to(device)

        # Compute model embedding
        with torch.no_grad():
            embeddings = model(input)

        embedding_tuples.extend(zip(names, embeddings))

        # Log progress
        i += 1
        if i % 100 == 0:
            speed = i / (time.time() - time_start)
            eta = timedelta(seconds=int((num_batches - i) / speed))
            logging.info(f"Batch {i:5d}/{num_batches:4d} - Speed {speed:.2f} batches/s - ETA: {eta}")

    logging.info('Finished inference')

    batch_size = cfg['dataloader']['batch_size'] if 'batch_size' in cfg['dataloader'] else 1
    sample_speed =  (time.time() - time_start) / (i * batch_size)
    logging.info(f'Average inference time: {sample_speed:.4f} s/sample')

    time_start = time.time()

    # Upsert into Pinecone
    pinecone_api_key = os.getenv("PINECONE_API_KEY") # Pulling this from .env
    pc = Pinecone(pinecone_api_key)
    index = pc.Index("sentinel2")

    vectors=[]
    for name, embedding in embedding_tuples:
        vectors.append(
            {"id": name, "values":embedding}
        )
    index.upsert(vectors)

    logging.info(f'*** {len(embedding_tuples)} embeddings upserted into Pinecone. Took {(time.time() - time_start):.4f} s ***')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--config_file', type=str, required=True, help='Path to config file')
    parser.add_argument('-o', '--output_dir', type=str, default=None,
                        help='Path to output dir for embeddings'
                             '(default: output/embeddings/<model>/<dataset>)')
    parser.add_argument('-d', '--dataset', type=str,
                        help='Overwrite the dataset name in the config file')
    parser.add_argument('--input_size', type=int,
                        help='Overwrite the size of the model input in the config file')
    parser.add_argument('--data_dir', type=str,
                        help='Path to data directory (default `data`)')
    parser.add_argument('--log_level', type=str, default='INFO',
                        help='Log level (DEBUG, INFO, WARNING, ERROR)')
    parser.add_argument('--log_file', type=str, default=None,
                        help='Log file')
    args = parser.parse_args()

    # Load config file
    with open(args.config_file, 'r') as f:
        cfg = yaml.safe_load(f)

    # Overwrite dataset optional args
    if args.dataset:
        cfg['dataset']['name'] = args.dataset
    if args.input_size:
        cfg['model']['img_size'] = args.input_size

    # Set data dir as env variable if specified
    if args.data_dir:
        os.environ['DATA_DIR'] = args.data_dir

    # init logger
    current_time = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H-%MZ")
    log_file = args.log_file or f"logs/{current_time}_{cfg['model']['name']}_{cfg['dataset']['name']}.log"
    os.makedirs(os.path.dirname(log_file), exist_ok=True)
    logging.basicConfig(
        level=args.log_level.upper(),
        handlers=[logging.FileHandler(log_file), logging.StreamHandler()],
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )

    logging.info(f'Config:\n {yaml.dump(cfg)}')

    try:
        run_inference(cfg, args)
    except Exception as e:
        # log potential error
        logging.error(f'{type(e)}: {e}')
        raise e
