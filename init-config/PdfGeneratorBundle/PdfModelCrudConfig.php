<?php

declare(strict_types=1);


use App\Crudit\Datasource\PdfModelDatasource;
use Lle\CruditBundle\Contracts\CrudConfigInterface;
use Lle\CruditBundle\Crud\AbstractCrudConfig;
use Lle\CruditBundle\Dto\Action\ItemAction;
use Lle\CruditBundle\Dto\Field\Field;
use Lle\CruditBundle\Dto\Icon;
use Lle\CruditBundle\Dto\Path;

class PdfModelCrudConfig extends AbstractCrudConfig
{
    public function __construct(
        PdfModelDatasource $datasource,
    ) {
        $this->datasource = $datasource;
    }

    /**
     * @return array<Field|Field[]>
     */
    public function getFields(string $key): array
    {
        $libelle = Field::new('libelle');
        $code = Field::new('code');
        $description = Field::new('description');

        return match ($key) {
            CrudConfigInterface::INDEX, CrudConfigInterface::SHOW => [
                $libelle,
                $code,
                $description,
            ],
            default => [],
        };
    }

    public function getListActions(): array
    {
        $actions = parent::getListActions();

        unset($actions[CrudConfigInterface::ACTION_EXPORT]);

        return $actions;
    }

    public function getItemActions(): array
    {
        $actions = parent::getItemActions();

        $actions[] = ItemAction::new(
            'action.pdf_model.download',
            Path::new('lle_pdf_generator_download_model'),
            Icon::new('file-download'),
        )
            ->setCssClass('btn btn-primary btn-sm');

        $actions[] = ItemAction::new(
            'action.pdf_model.show',
            Path::new('lle_pdf_generator_show_model'),
            Icon::new('file-pdf'),
        )
            ->setCssClass('btn btn-primary btn-sm')
            ->setTarget('_blank');

        return $actions;
    }

    public function getRootRoute(): string
    {
        return 'app_crudit_pdfmodel';
    }
}
